require 'forwardable'
require 'grit'
require 'yaml'

ENV['PATH'] = File.join(File.dirname(__FILE__), '/../bin') + ':' + ENV['PATH']

describe 'bt-go' do
  def self.project &block
    let!(:project) { Project.at(Dir.mktmpdir, &block) }

    subject { project }
  end

  describe "a repo with a bt build" do
    project do |p|
      p.passing_stage :first, 'run' => 'echo "blah" > new_file',
                              'results' => ['new_file']
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

    it { should have_bt_ref 'first', project.head }

    context "its results tree" do
      subject { project.bt_ref('first', project.head).tree }

      it { should have_file_content('new_file', "blah\n") }
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

    context "the initial commit" do
      subject { project.bt_ref('first', project.head).commit }

      its(:message) { should == 'FAIL bt loves you' }
    end
  end

  describe "a repo with a failing bt build" do
    project { |p| p.failing_stage :failing }

    before { project.build }

    context "the initial commit" do
      subject { project.bt_ref('failing', project.head).commit }

      its(:message) { should == 'FAIL bt loves you' }
    end

    it { should_not be_ready }
  end

  describe "a repo with a failing dependant stage" do
    project do |p|
      p.failing_stage 'first'
      p.passing_stage 'second', 'needs' => ['first']
    end

    before { project.build }

    context "the first build result" do
      subject { project.bt_ref('first', project.head).commit }

      its(:message) { should == 'FAIL bt loves you' }
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
      it { should have_bt_ref 'first', project.head }

      context "its results tree" do
        subject { project.bt_ref('first', project.head).tree }

        it { should have_file_content('new_file', "blah\n") }
      end

      context "its commit" do
        subject { project.bt_ref('first', project.head).commit }

        its(:message) { should == "PASS bt loves you" }
      end

      it { should have_results :first => first_result }
   end

    context "with second stage built" do
      before { 2.times { project.build } }

      it { should_not be_ready }
      it { should have_bt_ref 'second', project.head }

      context "its results tree" do
        subject { project.bt_ref('second', project.head).tree }

        it { should have_file_content('new_file', "blah\nblah blah\n") }
      end

      context "its commit" do
        subject { project.bt_ref('second', project.head).commit }

        its(:message) { should == "PASS bt loves you" }
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

RSpec::Matchers.define :have_bt_ref do |stage, commit|
  match do |project|
    project.bt_ref(stage, commit)
  end
end

RSpec::Matchers.define :have_file_content do |name, content|
  match do |tree|
    (tree / name).data == content
  end

  failure_message_for_should do |tree|
    "Expected #{name.inspect} to have content #{content.inspect} but had #{(tree / name).data.inspect}"
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

class Project
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

  def stage name, stage_config
    FileUtils.makedirs("#{@repo.working_dir}/stages")
    File.open("#{@repo.working_dir}/stages/#{name.to_s}", 'w') do |f|
      f.write(stage_config)
    end
    @repo.add "stages/#{name.to_s}"
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
    stage(name, generator_config)
    File.chmod(0755, "#{@repo.working_dir}/stages/#{name.to_s}")
  end

  def bt_ref stage, commit
    Ref.find_all(self.repo).detect { |r| r.name == "#{commit.sha}/#{stage}" }
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
