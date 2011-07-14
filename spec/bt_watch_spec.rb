require 'support/project'

ENV['PATH'] = File.join(File.dirname(__FILE__), '/../bin') + ':' + ENV['PATH']

describe 'bt-watch' do
  include Project::RSpec

  project do |p|
    p.passing_stage 'first'
  end

  after_executing_async 'bt-watch --debug 2>&1 > /tmp/out.txt' do
    it { should have_results_for(project.head).including_stages('first').eventually }

#    there should be a result for the first commit
#  when i commit new code
#    there should be a result for the second commit

    context "when a change is committed" do
      before { subject.commit_change }
      
      it do
        should have_results_for(project.head).including_stages('first').within(:timeout => 60, :interval => 5)
      end
    end
  end
end

