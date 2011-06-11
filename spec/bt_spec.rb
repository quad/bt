require 'bt'
require 'grit'

describe BT do
  def self.project &block
    let!(:project) { BT::Project.at(Dir.mktmpdir, &block) }

    subject { project }
  end

  describe "a repo with a bt build" do
    project do |p|
      p.stage :first, <<-eos
  run: echo \"blah\" > new_file
  results:
    - new_file
      eos
    end
    
    let!(:initial_commit) { project.repo.commits.first }

    before { project.build }

    it { should have_bt_ref 'first', initial_commit }

    context "its results tree" do
      subject { project.repo.tree("bt/first/#{initial_commit.sha}") }

      it { should have_file_content('new_file', "blah\n") }
    end
  end

  describe "a repo with a failing bt build" do
    project do |p|
      p.stage :failing, <<-eos
run: exit 1
      eos
    end
   
    let!(:initial_commit) { project.repo.commits.first }

    before { project.build }

    context "the initial commit" do
      subject { project.bt_ref('failing', initial_commit).commit } 

      its(:message) { should == 'FAIL bt loves you' }
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

    let(:source_commit) { project.repo.commits.first }
    
    context "with first stage built" do
      before { project.build }
      
      it { should have_bt_ref 'first', source_commit }

      context "its results tree" do
        subject { project.bt_ref('first', source_commit).tree }

        it { should have_file_content('new_file', "blah\n") }
      end

      context "its commit" do
        subject { project.bt_ref('first', source_commit).commit }

        its(:message) { should == "PASS bt loves you" }
      end
   end

    context "with second stage built" do
      before { 2.times { project.build } }

      it { should have_bt_ref 'second', source_commit }

      context "its results tree" do
        subject { project.bt_ref('second', source_commit).tree }

        it { should have_file_content('new_file', "blah\nblah blah\n") }
      end
    
      context "its commit" do
        subject { project.bt_ref('second', source_commit).commit }

        its(:message) { should == "PASS bt loves you" }
      end
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

module BT
  class Ref < Grit::Ref
    extend Forwardable

    def_delegator :commit, :tree

    def self.prefix
      "refs/bt"
    end
  end

  class Project
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

    def bt_ref stage, commit
      BT::Ref.find_all(self.repo).detect { |r| r.name == "#{stage}/#{commit.sha}" }
    end

    def build
      output = %x{./bin/bt -d go #{repo.working_dir} 2>&1}
      raise output unless $?.exitstatus.zero?
    end
  end
end
