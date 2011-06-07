require 'bt'
require 'grit'

describe "a repo with a bt build" do
  before do
    @repo = BT::Builder.repo_at(Dir.mktmpdir) do |r|
      r.stage 'first', <<-eos
run: echo \"blah\" > new_file
results:
  - new_file
      eos
    end

    %x{./bin/bt go #{@repo.working_dir} 2> /dev/null}

    @initial_commit = @repo.commits.first
  end

  subject { @repo }

  it { should have_head "bt/#{@initial_commit.sha}/first" }

  context "its results tree" do
    subject { @repo.tree("bt/#{@initial_commit.sha}/first") }

    it { should have_file_content('new_file', "blah\n") }
  end
end

describe "a repo with two dependent stages" do
  before do
    @repo = BT::Builder.repo_at(Dir.mktmpdir) do |r|
      r.stage 'first', <<-eos
run: echo \"blah\" > new_file
results:
  - new_file
      eos

      r.stage 'second', <<-eos
run: echo \"blah blah\" >> new_file
needs:
  - first
results:
  - new_file
      eos
    end
  end

  subject { @repo }

  let(:first_commit) { @repo.commits.first }
  
  context "first stage built" do
    before { %x{./bin/bt go #{@repo.working_dir} 2> /dev/null}; }
    
    it { should have_head "bt/#{first_commit.sha}/first" }

    context "its results tree" do
      subject { @repo.tree("bt/#{first_commit.sha}/first") }

      it { should have_file_content('new_file', "blah\n") }
    end
 end

  context "second stage built" do
    before { 2.times { %x{./bin/bt go #{@repo.working_dir} 2> /dev/null} } }

    it { should have_head "bt/#{first_commit.sha}/second" }

    context "its results tree" do
      subject { @repo.tree("bt/#{first_commit.sha}/second") }

      it { should have_file_content('new_file', "blah\nblah blah\n") }
    end
  end
end

RSpec::Matchers.define :have_head do |head|
  match do |repo|
    repo.is_head?(head)
  end
end

RSpec::Matchers.define :have_file_content do |name, content|
  match do |tree|
    (tree / name).data == content
  end
end

module BT
  class Builder
    def self.repo_at dir, &block
      FileUtils.cd(dir) do |dir|
        return new(dir, &block).repo
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
      File.open("#{@repo.working_dir}/stages/#{name}", 'w') do |f|
        f.write(stage_config)
      end
      @repo.add "stages/#{name}"
    end
  end
end

