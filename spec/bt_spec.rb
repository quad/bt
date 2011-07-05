require 'support/project'

ENV['PATH'] = File.join(File.dirname(__FILE__), '/../bin') + ':' + ENV['PATH']

describe 'bt-go' do
  include Project::RSpec

  describe "a repo with a bt build" do
    project do |p|
      p.stage 'first', <<-eos
run: echo \"blah\" > new_file
results:
  - new_file
      eos
    end

    its(:definition) do
      should == <<-EOS
--- 
first: 
  needs: []

  results: 
  - new_file
  run: echo \"blah\" > new_file
      EOS
    end

    executed 'bt-go' do
      result_of stage { [project.head, 'first'] } do
        it { should have_file_content_in_tree 'new_file', "blah\n" }
      end
    end
  end

  describe "a repo which expects results that are not generated" do
    project do |p|
      p.stage :first, <<-eos
  run: exit
  results:
    - new_file
      eos
    end

    executed 'bt-go' do
      result_of stage { [project.head, 'first'] } do
        its('commit.message') { should == 'FAIL bt loves you' }
      end
    end
  end

  describe "a repo with a failing bt build" do
    project { |p| p.failing_stage :failing }

    executed 'bt-go --once' do
      result_of stage { [project.head, 'failing'] } do
        its('commit.message') { should == "FAIL bt loves you" }
      end

      it { should_not be_ready }
    end
  end

  describe "a repo with a failing dependant stage" do
    project do |p|
      p.failing_stage 'first'
      p.passing_stage 'second', 'needs' => ['first']
    end

    executed 'bt-go --once' do
      result_of stage { [project.head, 'first'] } do
        its('commit.message') { should == "FAIL bt loves you" }
      end

      it { should_not be_ready }
    end
  end

  describe "a repo with two dependent stages" do
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

    its(:definition) do
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

    let(:first_result) { project.bt_ref('first', project.head).commit }
    let(:second_result) { project.bt_ref('second', project.head).commit }

    it { should be_ready }

    executed 'bt-go --once' do
      it { should be_ready }

      result_of stage { [project.head, 'first'] } do
        it { should have_file_content_in_tree 'new_file', "blah\n" }
        its('commit.message') { should == "PASS bt loves you" }
      end

      it { should have_results :first => first_result }
    end

    executed 'bt-go' do
      it { should_not be_ready }

      result_of stage { [project.head, 'second'] } do
        it { should have_file_content_in_tree 'new_file', "blah\nblah blah\n" }
        its('commit.message') { should == "PASS bt loves you" }
      end

      it { should have_results :first => first_result, :second => second_result }
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
y ({
   'stage' => {'run' => 'exit 0', 'needs' => [], 'results' => []},
   'another' => {'run' => 'exit 0', 'needs' => [], 'results' => []}
})
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


    its(:definition) do
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

