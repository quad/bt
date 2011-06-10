module BT
  require 'andand'
  require 'forwardable'
  require 'tempfile'
  require 'tmpdir'
  require 'yaml'
  require 'grit'

  MSG = 'bt loves you'
  
  class Stage < Struct.new(:commit, :filename, :needs, :run, :results)
    extend Forwardable

    # Temporary: fix Grit or go home.
    class Ref < Grit::Ref
      def self.prefix
        "refs/bt"
      end
    end

    def ref
      Ref.find_all(repo).detect { |r| r.name == "#{name}/#{commit.sha}" }
    end

    def repo
      commit.repo
    end

    def initialize(commit, filename)
      super(commit, filename, [], nil, [])
      merge! YAML::load (commit.tree / filename).data
    end

    def name
      File.basename(filename)
    end

    def needs
      self[:needs].map do |stage_name|
        Stage.new commit, File.join(File.dirname(filename), stage_name)
      end
    end

    def branch_name
      "refs/bt/#{name}/#{commit.sha}"
    end

    def build
      status = nil

      # TODO: Log the whole build transaction.
      Dir.mktmpdir do |tmp_dir|
        repo.git.clone({:recursive => true}, repo.path, tmp_dir)

        Repository.new(tmp_dir) do |r|
          # Merge
          needs.each do |n|
            r.git.pull({:raise => true, :squash => true}, 'origin', n.branch_name)
          end

          r.git.reset({:raise => true, :mixed => true}, commit.sha)

          # Build
          status, log = run

          # Commit results
          message = "#{status.zero? ? :PASS : :FAIL} #{MSG}\n\n#{log}"
          r.commit message, results
        end

        # Merge back
        repo.git.fetch({:raise => true}, tmp_dir, "+HEAD:#{branch_name}")
      end

      status
    end

    def ready? pipeline
      (needs - pipeline.done).empty?
    end



    private
    def merge!(hash)
      hash.each_pair { |k, v| self[k] = v }
    end

    def run
      result = ""
      IO.popen('sh -', 'r+') do |io|
        io << self[:run]
        io.close_write

        begin
          while c = io.readpartial(4096)
            [result, $stdout].each {|o| o << c}
          end
        rescue EOFError
        end
      end
      [$?.exitstatus, result]
    end
  end

  class Repository < Struct.new(:path)


    def head
      @repo.head
    end

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

    def commit message, files = []
      files.each { |fn| git.add({}, fn) }
      @repo.git.commit({
        :raise => true,
        :author=>'Build Thing <build@thing.invalid>',
        :"allow-empty" => true, 
        :cleanup=>'verbatim',
        :message => "#{message.strip}"
      })
    end

    def git
      @repo.git
    end

    def pull
      @repo.git.fetch({:raise => true}, 'origin')
    end

    def push
      @repo.git.push({:raise => true}, 'origin')
    end
  end

  class Pipeline < Struct.new :commit
    def ready
      incomplete.select { |stage| stage.ready? self }
    end

    def stages
      (commit.tree / 'stages').blobs.map do |stage_blob|
        Stage.new(commit, "stages/#{stage_blob.basename}")
      end
    end

    def done
       stages.select do |stage|
        if ref = stage.ref
          ['OK', 'PASS'].any? {|status| ref.commit.message.start_with? status}
        else
          false
        end
      end
    end

    def incomplete
      stages - done
    end
  end
end
