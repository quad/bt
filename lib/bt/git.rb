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

    def workspace depends, &block
      repository.working_tree do |t|
        depends.each { |n| t.checkout_result n}

        name, message, files = yield

        t.commit message, files

        add_result t, name
      end
    end

    def add_result working_tree, name
      repository.fetch working_tree, self, name
    end

    def to_s
      "#{message.lines.first.chomp} (#{sha})"
    end
  end

  class Repository < Struct.new(:path)
    # TODO: Mirror is not the right word.
    def self.mirror uri, &block
      Dir.mktmpdir(['bt', '.git']) do |tmp_dir|
        repo = Grit::Repo.new(tmp_dir).fork_bare_from uri
        Mirror.new repo.path, &block
      end
    end

    def working_tree &block
      Dir.mktmpdir do |tmp_dir|
        git.clone({:recursive => true}, path, tmp_dir)
        WorkingTree.new tmp_dir, &block
      end
    end

    def initialize(path, &block)
      super(path)
      @repo = Grit::Repo.new(path)

      Dir.chdir(path) { yield self } if block_given?
    end

    def head
      Commit.new self, @repo.head.commit
    end

    def result commit, name
      ref = refs.detect { |r| r.name == "#{name}/#{commit.sha}" }
      Commit.new self, ref.commit if ref
    end

    def fetch repository, commit, name
      result = repository.result(commit, name)

      git.fetch({:raise => true}, repository.path, "+HEAD:#{Ref.prefix}/#{name}/#{commit.sha}")
    end

    private

    # Temporary: fix Grit or go home.
    class Ref < Grit::Ref
      def self.prefix
        'refs/bt'
      end
    end

    def git
      @repo.git
    end

    def refs
      Ref.find_all(@repo)
    end

    class Mirror < Repository
      def update
        # TODO: Make a behavior test to show "+" means the remote repository is
        # the eternal source of truth.
        git.fetch({:raise => true}, 'origin', "+#{Ref.prefix}/*:#{Ref.prefix}/*")
      end

      def push
        # TODO: Raise on failure (double-build, network-failures, etc.).
        #
        # Causes bt-watch to crash-- and if it is to catch something, then we
        # need to think about what exceptions we want to expose.
        
        git.push({:raise => true}, 'origin', "#{Ref.prefix}/*") end end

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

      def checkout_result commit
        git.merge({:raise => true, :squash => true}, commit.sha)
        git.reset({:raise => true, :mixed => true}, commit.sha)
      end
    end
  end
end
