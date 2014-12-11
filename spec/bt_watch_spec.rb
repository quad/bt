require 'support/spec_helper'

ENV['PATH'] = File.join(File.dirname(__FILE__), '/../bin') + ':' + ENV['PATH']

describe 'bt-watch' do
  include Project::RSpec
  include TimingMatchers

  project do |p|
    p.passing_stage 'first'
  end

  after_executing_async 'bt-watch' do
    it { should eventually(have_results_for(project.head).including_stages('first')) }

    context "when polling for changes and a change is commited" do
      def self.precondition &block
        before do
          begin
            Timeout.timeout(20) do
              until instance_eval &block
                sleep 1
              end
            end

          rescue TimeoutError
            raise "Precondition not met"
          end
        end
      end

      precondition { project.bt_ref('first', project.head) }

      before { project.commit_change }

      it { should eventually(have_results_for(project.head).including_stages('first')) }
    end
  end
end

