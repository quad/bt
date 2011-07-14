module BT
  require 'andand'
  require 'forwardable'
  require 'grit'
  require 'tmpdir'
  require 'uuid'

  class Commit < Struct.new :repository, :commit
    extend Forwardable

    def_delegators :commit, :tree, :sha, :message

    def result name
      repository.result(self, name)
    end

    def workspace depends, &block
      repository.working_tree do |t|
        depends.each { |n| t.checkout_result n }

        name, message, files = yield

        t.commit message, files

        add_result t, name
      end
    end

    def add_result working_tree, name
      repository.fetch working_tree, self, name
    end

    def to_hash
      {'message' => message, 'sha' => sha}
    end

    def to_s
      "#{message.lines.first.chomp} (#{sha})"
    end
  end

  class Repository < Struct.new(:path)
    # TODO: Mirror is not the right word.
    def self.mirror uri, &block
      Dir.mktmpdir(['bt', '.git']) do |tmp_dir|
        repo = Grit::Repo.new(tmp_dir).fork_bare_from uri, :timeout => false
        Mirror.new repo.path, &block
      end
    end

    def working_tree commit = 'HEAD', &block
      Dir.mktmpdir do |tmp_dir|
        # TODO: Find a better way of handling timeouts/long operations
        git.clone({:recursive => true, :timeout => false}, path, tmp_dir)
        WorkingTree.new tmp_dir do |tree|
          tree.branch_of commit
          block.call tree
        end
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

    def commit name
      Commit.new self, @repo.commit(name)
    end

    def commits options = {}
      actual_options = {:start => @repo.head.name, :skip => 0, :max_count => 10}.merge(options)

      grit_commits = @repo.commits(actual_options[:start], actual_options[:max_count], actual_options[:skip])
      grit_commits.map do |c|
        Commit.new self, c
      end
    end

    def result commit, name
      ref = refs.detect { |r| r.name == "#{commit.sha}/#{name}" }
      Commit.new self, ref.commit if ref
    end

    def fetch repository, commit, name
      result = repository.result(commit, name)

      git.fetch({:raise => true}, repository.path, "+HEAD:#{Ref.prefix}/#{commit.sha}/#{name}")
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
        fetch_results
        fetch_candidates
      end

      def push
        # TODO: This should probably throw an exception.
        #
        # This is a general failure right now.
        #
        # But what if we just lost network connectivity?
        begin
          git.push({:raise => true }, 'origin', "#{Ref.prefix}/*")

          true
        rescue Grit::Git::CommandFailed
          false
        end
      end

      private

      def fetch_results
        # TODO: Make a behavior test to show "+" means the remote repository is
        # the eternal source of truth.
        git.fetch({:raise => true, :timeout => false}, 'origin', "+#{Ref.prefix}/*:#{Ref.prefix}/*")
      end

      def fetch_candidates
        git.fetch({:raise => true, :timeout => false}, 'origin', "+refs/heads/*:refs/heads/*")
      end

    end

    class WorkingTree < Repository
      def commit message, files = []
        files.each { |fn| git.add({:force => true, :raise => true}, fn) }
        git.commit({
          :raise => true,
          :author => 'Build Thing <build@thing.invalid>',
          :'allow-empty' => true,
          :cleanup => 'verbatim',
          :file => '-',
          :input => message.strip,
        })
      end

      def branch_of sha
        git.checkout({:raise => true, :b => true}, UUID.new.generate, sha)
      end

      def checkout_result commit
        git.merge({:raise => true, :squash => true}, commit.sha)
        git.reset({:raise => true, :mixed => true}, commit.sha)
      end
    end
  end
end
