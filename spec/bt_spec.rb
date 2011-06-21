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

    let!(:initial_commit) { project.repo.commits.first }

    after_executing 'bt-go --stage second' do
      it { should have_bt_ref 'first', initial_commit }
      it { should have_bt_ref 'second', initial_commit }
      it { should_not have_bt_ref 'third', initial_commit }
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

    let(:first_result) { project.bt_ref('first', project.head).commit }
    let(:second_result) { project.bt_ref('second', project.head).commit }

    it { should be_ready }

    after_executing 'bt-go --once' do
      it { should be_ready }

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
end

