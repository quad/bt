require 'yaml'
require 'grit'
require 'forwardable'
require 'open3'
require 'json'

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

      def after_executing_async command, &block
        context "after executing #{command} asynchronously" do
          let(:watch_thread) do
            stdin, stdout, stderr, thread = subject.execute_async(command)
            thread
          end

          before { watch_thread }

          instance_eval &block

          after { Process.kill('TERM', watch_thread.pid) }
        end
      end

      def result_of_executing command, &block
        describe "the result of executing #{command}" do
          subject { project.execute command }

          it &block
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

    def execute command, debug = false
      output = nil
      FileUtils.cd repo.working_dir do
        output = %x{#{command} #{debug ? '--debug' : ''} 2>&1}
        raise output unless $?.exitstatus.zero?
      end
      output
    end

    def execute_async command
      ios = []
      FileUtils.cd repo.working_dir do
        ios = Open3.popen3(command)
      end
      ios
    end

    def build
      output = %x{bt-go --once --debug --directory #{repo.working_dir} 2>&1}
      raise output unless $?.exitstatus.zero?
    end

    def results
      output = %x{bt-results --debug #{repo.working_dir} 2>&1}
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
  chain :containing do |content|
    @content = content
  end

  match do |commit|
    @blob = commit.tree / name

    if @content
      @blob && @blob.data == @content
    else
      @blob
    end
  end

  failure_message_for_should do |commit|
    msg = "Expected #{commit.inspect} to have blob '#{name}'"
    msg << " containing '#{@content.inspect}' but got '#{@blob.data.inspect}'" if @blob && @content
    msg
  end
end

RSpec::Matchers.define :have_results_for do |commit|
  match do |project|
    actual_results = JSON.parse(project.execute("bt-results --format json --commit #{commit.sha} \"#{project.repo.path}\""))

    result_stages = actual_results[commit.sha]

    interesting_stages = @include_stages or result_stages.keys

    interesting_stages and interesting_stages.all? do |stage_name|
      stage = result_stages[stage_name]
      !stage.empty?
    end
  end

  chain :including_stages do |*stages|
    @include_stages = stages
  end
end

class RSpec::Matchers::Matcher
  def within options = {}
    WithinMatcher.new self, options
  end

  def eventually
    within :timeout => 20, :interval => 1
  end
end

module RSpec
  module Matchers
    class WithinMatcher
      def initialize matcher, options
        @matcher = matcher
        @options = {:interval => 0.1, :timeout => 1}.merge(options)
      end

      def matches? actual
        Timeout.timeout(@options[:timeout]) do
          until @matcher.matches?(actual)
            sleep @options[:interval]
          end
        end
        true
      rescue Timeout::Error
        false
      end

      def description
        "#{@matcher.description} within #{@options[:timeout]} seconds"
      end

      def failure_message_for_should
        "#{@matcher.failure_message_for_should} within #{@options[:timeout]} seconds"
      end

      def failure_message_for_should_not
        "#{@matcher.failure_message_for_should_not} within #{@options[:timeout]} seconds"
      end
    end
  end
end

