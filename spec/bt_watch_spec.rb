require 'support/project'

ENV['PATH'] = File.join(File.dirname(__FILE__), '/../bin') + ':' + ENV['PATH']

describe 'bt-watch' do
  include Project::RSpec

  project do |p|
    p.passing_stage 'first'
  end

  def self.after_executing_async command, &block
    context "after executing #{command} asynchronously" do
      let(:watch_thread) do
        stdin, stdout, stderr, thread = subject.execute_async(command)
        thread
      end

      before { watch_thread }

      instance_eval &block

      after { Process.kill('HUP', watch_thread.pid) }
    end
  end

  after_executing_async 'bt-watch' do
    it { should have_bt_ref('first', project.head).within(:timeout => 20, :interval => 1) }
  end
end

class RSpec::Matchers::Matcher
  def within options = {}
    WithinMatcher.new self, options
  end
end

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
    @matcher.failure_message_for_should
  end

  def failure_message_for_should_not
    @matcher.failure_message_for_should_not
  end
end
