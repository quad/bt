require 'support/spec_helper'
require 'json'

ENV['PATH'] = File.join(File.dirname(__FILE__), '/../bin') + ':' + ENV['PATH']

describe 'bt-stages' do
  include Project::RSpec

  describe 'a project with a single static stage specification' do
    project do |p|
      p.stage :first, <<-eos
  run: echo \"blah\" > new_file
  results:
    - new_file
      eos

      p.stage :second, <<-eos
  run: echo \"blah blah\" >> new_file
  needs:
    - first
  results:
    - new_file
      eos
    end

    result_of_executing 'bt-stages' do
      should == <<-EOS
---
first:
  needs: []
  results:
  - new_file
  run: echo \"blah\" > new_file
second:
  needs:
  - first
  results:
  - new_file
  run: echo \"blah blah\" >> new_file
      EOS
    end

    result_of_executing 'bt-stages --format json' do
      should == {
        'first' => {
          'needs' => [],
          'results' => ['new_file'],
          'run' => 'echo "blah" > new_file'
        },
        'second' => {
          'needs' => ['first'],
          'results' => ['new_file'],
          'run' => 'echo "blah blah" >> new_file'
        }
      }.to_json
    end
  end

  describe "a repo with a stage generator" do
    project do |p|
      p.stage :first, <<-eos
  run: exit 0
  results:
    - new_file
      eos

      p.stage_generator :generator, <<-eos
#!/usr/bin/env ruby
require 'yaml'
puts ({
   'stage' => {'run' => 'exit 0', 'needs' => [], 'results' => []},
   'another' => {'run' => 'exit 0', 'needs' => [], 'results' => []}
}).to_yaml
      eos

      p.file 'stages/lib/', 'stage', <<-eos
---
stage_from_lib:
  run: exit 0
  results: []
  needs: []
      eos

      p.stage_generator :lib_generator, <<-eos
#!/bin/sh -e

cat `dirname $0`/lib/stage
      eos
    end


    result_of_executing 'bt-stages' do
      should == <<-eos
---
first:
  needs: []
  results:
  - new_file
  run: exit 0
stage:
  run: exit 0
  needs: []
  results: []
another:
  run: exit 0
  needs: []
  results: []
stage_from_lib:
  run: exit 0
  results: []
  needs: []
eos
    end
  end
end
