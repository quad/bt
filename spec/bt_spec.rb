require 'bt'
require 'grit'

describe "a repo with a bt build" do
  before do
    FileUtils.cd(Dir.mktmpdir) do |dir|
      @repo = Grit::Repo.init(dir)
      FileUtils.makedirs("#{@repo.working_dir}/stages")
      File.open("#{@repo.working_dir}/stages/first", 'w') {|f| f.write("run: echo \"blah\" > new_file\nresults:\n  - new_file") }
      @repo.add("stages/first")
      @repo.commit_all("Initial commit")
      @initial_commit = @repo.commits.first
    end

    %x[./bin/bt go #{@repo.working_dir} 2> /dev/null]
  end

  subject { @repo }

  it { should have_head "bt/#{@initial_commit.sha}/first" }

  context "its results tree" do
    subject { @repo.tree("bt/#{@initial_commit.sha}/first") }

    it { should have_file_content('new_file', "blah\n") }
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
