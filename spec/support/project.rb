require 'yaml'
require 'grit'
require 'forwardable'

module Project
  module RSpec
    def self.included base
      base.extend ClassMethods
    end

    module ClassMethods
      alias :stage :proc
      alias :commit :proc

      def project &block
        let!(:project) { Model.at(Dir.mktmpdir, &block) }

        subject { project }
      end

      def after_executing command, &block
        context "when '#{command}' has executed" do
          before { project.execute command }

          instance_eval &block
        end
      end

      def result_of stage_proc, &block
       it {
         commit, stage_name = instance_eval(&stage_proc)
         should have_bt_ref stage_name, commit
       }

       describe "the result for stage" do
          define_method(:subject) do
            commit, stage_name = instance_eval(&stage_proc)
            super().bt_ref(stage_name, commit)
          end

          instance_eval &block
        end
      end
    end
  end

  class Model
    class Ref < Grit::Ref
      extend Forwardable

      def_delegator :commit, :tree

      def self.prefix
        "refs/bt"
      end
    end

    DEFAULT_STAGE_DEFINITION = {'run' => 'exit 0', 'needs' => [], 'results' => []}

    def self.at dir, &block
      FileUtils.cd(dir) do |dir|
        return new(dir, &block)
      end
    end

    attr_reader :repo

    def initialize dir, &block
      @repo = Grit::Repo.init(dir)
      yield self
      @repo.commit_all("Initial commit")
    end

    def file directory, name, content, mode = 0444
      dir = File.join(@repo.working_dir, directory.to_s)
      FileUtils.makedirs(dir)
      file_name = File.join(dir, name.to_s)
      File.open(file_name, 'w') { |f| f.write content }
      File.chmod(mode, file_name)
      @repo.add directory.to_s
    end

    def stage name, stage_config
      file 'stages', name, stage_config
    end

    def failing_stage name, overrides = {}
      stage name, YAML.dump(DEFAULT_STAGE_DEFINITION.merge('run' => 'exit 1').merge(overrides))
    end

    def head
      repo.commits.first
    end

    def passing_stage name, overrides = {}
      stage name, YAML.dump(DEFAULT_STAGE_DEFINITION.merge(overrides))
    end

    def stage_generator name, generator_config
      file 'stages', name, generator_config, 0755
    end

    def bt_ref stage, commit
      Ref.find_all(self.repo).detect { |r| r.name == "#{commit.sha}/#{stage}" }
    end

    def execute command
      FileUtils.cd repo.working_dir do
        output = %x{#{command} --debug 2>&1}
        raise output unless $?.exitstatus.zero?
        output
      end
    end

    def build
      output = %x{bt-go --once --debug --directory #{repo.working_dir} 2>&1}
      raise output unless $?.exitstatus.zero?
    end

    def results
      output = %x{bt-results --debug --uri #{repo.working_dir} 2>&1}
      raise output unless $?.exitstatus.zero?
      output
    end

    def definition
      output = %x{bt-stages #{repo.working_dir}}
      raise output unless $?.exitstatus.zero?
      output
    end

    def ready?
      output = %x{bt-ready #{repo.working_dir}}
      raise output unless $?.exitstatus.zero?
      !output.empty?
    end
  end
end

RSpec::Matchers.define :have_bt_ref do |stage, commit|
  match do |project|
    project.bt_ref(stage, commit)
  end

  failure_message_for_should do |commit|
    "Expected commit #{commit.inspect} to have stage \"#{stage}\""
  end
end

RSpec::Matchers.define :have_blob do |name|
  match do |commit|
    @blob = commit.tree / name

    if @content
      @blob && @blob.data == @content
    else
      @blob
    end
  end

  chain :containing do |content|
    @content = content
  end

  failure_message_for_should do |commit|
    msg = "Expected #{commit.inspect} to have blob '#{name}'"
    msg << " containing '#{@content.inspect}' but got '#{@blob.data.inspect}'" if @blob && @content
    msg
  end
end

RSpec::Matchers.define :have_results do |results|
  match do |project|
    result_string = project.results
    results.all? do |stage, result_commit|
      result_string.index /^#{stage.to_s}: (PASS|FAIL) bt loves you \(#{result_commit.sha}\)$/
    end
  end
end

