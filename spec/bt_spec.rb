require 'support/project'
require 'forwardable'
require 'grit'
require 'bt/yaml'
require 'json'

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

    after_executing 'bt-go' do
      result_of stage { [project.head, 'first'] } do
        it { should have_blob('new_file').containing("blah\n") }
      end

      its(:ready_stages) { should be_empty }
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

    after_executing 'bt-go' do
      result_of stage { [project.head, 'first'] } do
        its('commit.message') { should == 'FAIL bt loves you' }
      end
    end
  end

  describe "a repo with a failing bt build" do
    project { |p| p.failing_stage :failing }

    after_executing 'bt-go --once' do
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

    after_executing 'bt-go --once' do
      result_of stage { [project.head, 'first'] } do
        its('commit.message') { should == "FAIL bt loves you" }
      end

      it { should_not be_ready }
    end
  end

  describe "a repo with a bt build, which has built a stage with needs" do
    project do |p|
      p.stage :first, <<-eos
  run: exit 0
      eos

      p.stage :second, <<-eos
  run: exit 0
  needs:
    - first
      eos

      p.stage :third, <<-eos
  run: exit 0
  needs:
    - second
      eos
    end

    after_executing 'bt-go --stage second', :raise => false do
      it { should_not have_results_for project.head }
    end

    after_executing 'bt-go --stage first' do
      it { should have_results_for(project.head).including_stages('first') }
      it { should_not have_results_for(project.head).including_stages('second', 'third') }

      after_executing 'bt-go --stage second' do
        it { should have_results_for(project.head).including_stages('first', 'second') }
        it { should_not have_results_for(project.head).including_stages('third') }
      end
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

    it { should be_ready }

    its(:ready_stages) { should == ["#{project.head.sha}/first"]}

    after_executing 'bt-go --once' do
      it { should be_ready }

      its(:ready_stages) { should == ["#{project.head.sha}/second"] }

      result_of stage { [project.head, 'first'] } do
        it { should have_blob('new_file').containing("blah\n") }
        its('commit.message') { should == "PASS bt loves you" }
      end

      it { should have_results_for(project.head).including_stages('first') }
    end

    after_executing 'bt-go' do
      it { should_not be_ready }

      result_of stage { [project.head, 'second'] } do
        it { should have_blob('new_file').containing("blah\nblah blah\n") }
        its('commit.message') { should == "PASS bt loves you" }
      end

      it { should have_results_for(project.head).including_stages('first', 'second') }
    end
  end

  describe "a project which has multiple upstream stages" do
    project do |p|
      p.stage :first, <<-eos
  run: touch first
  results:
    - first
      eos

      p.stage :second, <<-eos
  run: touch second
  results:
    - second
      eos

      p.stage 'third', <<-eos
run: exit 0
needs:
  - first
  - second
      eos
    end

    after_executing 'bt-go' do
      result_of stage { [ project.head, 'third' ] } do
        its('commit') { should have_parents project.bt_ref('first', project.head).commit, project.bt_ref('second', project.head).commit }
        it { should have_blob('first') }
        it { should have_blob('second') }
      end
    end
  end
end

