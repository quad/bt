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

    before { project.build }

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

    results_for_stage 'first' do
      it { should have_file_content_in_tree 'new_file', "blah\n" }
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

    before { project.build }

    results_for_stage 'first' do
      its('commit.message') { should == 'FAIL bt loves you' }
    end
  end

  describe "a repo with a failing bt build" do
    project { |p| p.failing_stage :failing }

    before { project.build }

    results_for_stage 'failing' do
      its('commit.message') { should == "FAIL bt loves you" }
    end

    it { should_not be_ready }
  end

  describe "a repo with a failing dependant stage" do
    project do |p|
      p.failing_stage 'first'
      p.passing_stage 'second', 'needs' => ['first']
    end

    before { project.build }

    results_for_stage 'first' do
      its('commit.message') { should == "FAIL bt loves you" }
    end

    it { should_not be_ready }
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

    it { should be_ready }

    context "with first stage built" do
      let(:first_result) { project.bt_ref('first', project.head).commit }

      before { project.build }

      it { should be_ready }

      results_for_stage 'first' do
        it { should have_file_content_in_tree 'new_file', "blah\n" }
        its('commit.message') { should == "PASS bt loves you" }
      end

      it { should have_results :first => first_result }
   end

    context "with second stage built" do
      before { 2.times { project.build } }

      it { should_not be_ready }

      results_for_stage 'second' do
        it { should have_file_content_in_tree 'new_file', "blah\nblah blah\n" }
        its('commit.message') { should == "PASS bt loves you" }
      end

      context "its results" do
        subject { project }

        let(:first_result) { project.bt_ref('first', project.head).commit }
        let(:second_result) { project.bt_ref('second', project.head).commit }

        it { should have_results :first => first_result, :second => second_result }
      end
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

eos
    end
  end
end

