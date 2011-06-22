require 'bt'
require 'yaml'
require 'support/file_builder'

include BT

describe StageSpecification do
  include FileBuilder

  executable_file :generator do |f|
    f.content <<-EOS
#!/usr/bin/env ruby
require 'yaml'
y({'stage' => {'results' => [], 'needs' => [], 'run' => 'exit 0'}})
    EOS
  end

  temporary_file :static do |f|
    f.content YAML.dump({'results' => [], 'needs' => [], 'run' => 'exit 0'})
  end

  describe "a stage specification with a single generated specification" do
    subject { StageSpecification.new [generator.path] }

    its(:to_hash) do
      should == {'stage' => {'results' => [], 'needs' => [], 'run' => 'exit 0'}}
    end
  end

  describe "a stage specification with a single static specification" do
    subject { StageSpecification.new [static.path] }

    its(:to_hash) do
      should == {File.basename(static.path) => {'results' => [], 'needs' => [], 'run' => 'exit 0'}}
    end
  end

  describe "a stage specification with a static and generated specification" do
    subject { StageSpecification.new [static.path, generator.path] }

    its(:to_hash) do
      should == {
        File.basename(static.path) => {'results' => [], 'needs' => [], 'run' => 'exit 0'},
        'stage' => {'results' => [], 'needs' => [], 'run' => 'exit 0'}
      }
    end
  end
end

