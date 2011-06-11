module BT
  require 'andand'
  require 'forwardable'
  require 'grit'
  require 'tmpdir'

  class Commit < Struct.new :repository, :commit
    extend Forwardable

    def_delegators :commit, :tree, :sha, :message

    def pipeline
      Pipeline.new self
    end

    def result name
      repository.result(self, name)
    end

    def working_tree &block
      Dir.mktmpdir do |tmp_dir|
        repository.clone tmp_dir
        WorkingTree.new(tmp_dir) { |r| yield r }
      end
    end

    def add_result working_tree, name
      repository.fetch working_tree, self, name
    end
  end

  class Repository < Struct.new(:path)
    # Temporary: fix Grit or go home.
    class Ref < Grit::Ref
      def self.prefix
        'refs/bt'
      end
    end

    # TODO: Kill
    attr_reader :repo

    def self.bare(path, &block)
      Dir.mktmpdir do |tmp_dir|
        git = Grit::Git.new(path)
        tmp_repo = git.clone({:raise => true, :mirror => true}, path, "#{tmp_dir}/.git")
        yield new tmp_dir
      end
    end

    def initialize(path, &block)
      super(path)
      @repo = Grit::Repo.new(path)

      Dir.chdir(path) { yield self } if block_given?
    end

    def cat_file commit, filename
      (@repo.tree(commit) / filename).andand.data or raise 'FAIL'
    end

    def head
      Commit.new self, @repo.head.commit
    end

    def refs
      Ref.find_all(@repo)
    end

    def result commit, name
      ref = refs.detect { |r| r.name == "#{name}/#{commit.sha}" }
      Commit.new self, ref.commit if ref
    end

    def fetch repository, commit, name
      result = repository.result(commit, name)

      git.fetch({:raise => true}, repository.path, "+HEAD:#{Ref.prefix}/#{name}/#{commit.sha}")
    end

    def clone target_directory
      git.clone({:recursive => true}, path, target_directory)
    end

    def update
      git.fetch({:raise => true}, 'origin')
    end

    def push
      git.push({:raise => true}, 'origin')
    end

    def git
      @repo.git
    end
  end

  class WorkingTree < Repository
    def commit message, files = []
      files.each { |fn| git.add({}, fn) }
      git.commit({
        :raise => true,
        :author => 'Build Thing <build@thing.invalid>',
        :'allow-empty' => true, 
        :cleanup => 'verbatim',
        :message => "#{message.strip}"
      })
    end

    def merge commits
      commits.each { |c| git.merge({:raise => true, :squash => true}, c.sha) }
    end
  end
end
