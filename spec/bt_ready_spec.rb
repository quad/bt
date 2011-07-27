require 'support/project'

ENV['PATH'] = File.join(File.dirname(__FILE__), '/../bin') + ':' + ENV['PATH']

describe 'bt-ready' do
  include Project::RSpec

  describe 'a project with a single static stage specification' do
    project do |p|
      p.stage :first, <<-eos
  run: echo \"blah\" > new_file
  results:
    - new_file
      eos
    end

    result_of_executing 'bt-ready' do
      should == "#{project.head.sha}/first\n"
    end

    result_of_executing 'bt-ready --commit HEAD' do
      should == "#{project.head.sha}/first\n"
    end

    context "with another stage added" do
      before do
        project.stage :second, <<-eos
run: exit 0
needs: []
results: []
        eos
        project.commit "Added second stage"
      end

      let(:head) { project.repo.git.rev_parse({}, 'HEAD') }
      let(:head_hat) { project.repo.git.rev_parse({}, 'HEAD^') }

      result_of_executing 'bt-ready --commit HEAD' do
        should == "#{head}/first\n#{head}/second\n"
      end

      result_of_executing 'bt-ready --commit HEAD\\^' do
        should == "#{head_hat}/first\n"
      end
    end
  end
end

