module BT
  require 'andand'
  require 'dnssd'
  require 'forwardable'
  require 'tmpdir'
  require 'yaml'

  MSG = 'bt loves you'

  class Commit < Struct.new(:repository, :name, :id)
    extend Forwardable

    def initialize(repository, name)
      id = repository.git("rev-parse --verify #{name}").chomp
      super(repository, name, id)
    end
  end

  class Stage < Struct.new(:commit, :filename, :needs, :run, :results)
    extend Forwardable

    def_delegator :commit, :repository

    def initialize(commit, filename)
      super(commit, filename, [], nil, [])
      merge! YAML::load repository.git "cat-file blob #{commit.id}:#{filename}"
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
      # TODO: Unique identifier after the stage.
      "bt/#{commit.id}/#{name}"
    end

    def build
      status = nil

      # TODO: Log the whole build transaction.
      Dir.mktmpdir do |tmp_dir|
        repository.git "clone --recursive -- . #{tmp_dir}", :system

        Repository.new(tmp_dir) do |r|
          # Merge
          needs.each do |n|
            r.git "pull --squash origin #{n.branch_name}", :system
          end

          r.git "reset --mixed #{commit.id}", :system

          # Build
          status, log = run

          # Commit results
          message = "#{status.zero? ? :PASS : :FAIL} #{MSG}\n\n#{log}"
          r.commit message, results
        end

        # Merge back
        repository.git "fetch #{tmp_dir} HEAD:#{branch_name}", :system
      end

      status
    end

    def lead(&block)
      DNSSD.register! commit.id, '_x-build-thing._tcp', nil, $$, do |r|
        yield self if block_given? && r.name == commit.id
        break
      end
    end

    def ready? dones
      (needs - dones).empty?
    end

    private
    def merge!(hash)
      hash.each_pair { |k, v| self[k] = v }
    end

    def run
      #TODO: Get a real logger
      output = ""
      IO.popen(self[:run]) do |io|
        io.each_char { |char| [output, $stdout].each {|o| o << char } }
      end
      [$?.exitstatus, output]
    end
  end

  class Repository < Struct.new(:path)
    def self.bare(path, &block)
      Dir.mktmpdir do |tmp_dir|
        system "git clone --mirror -- #{path} #{tmp_dir}"
        raise "FAIL" unless $?.exitstatus.zero?

        yield new tmp_dir
      end
    end

    def initialize(path, &block)
      super(path)
      refresh
      Dir.chdir(path) { yield self } if block_given?
    end

    def refresh
      @head = Commit.new self, 'HEAD'
    end

    def ready
      dones = done

      incomplete.select { |stage| stage.ready? dones }
    end

    def commit message, files = []
      files.each { |fn| git "add #{fn}" }
      git "commit --author='Build Thing <build@thing.invalid>' --allow-empty --cleanup=verbatim --file=-" do |pipe|
        pipe << message
        pipe.close_write
      end
    end

    def git(cmd, *options, &block)
      # TODO: More comprehensive error checking.
      Dir.chdir(path) do
        if block_given?
          IO.popen("git #{cmd}", 'w+') { |p| yield p }
        elsif options.include? :system
          system "git #{cmd}"
          raise "FAIL" unless $?.exitstatus.zero?
        else
          `git #{cmd}`
        end
      end
    end

    def pull
      git 'fetch origin', :system
    end

    def push
      git 'push origin', :system
    end

    private
    def stages
      git("ls-tree --name-only #{@head.id} stages/").split.map do |fn|
        Stage.new(@head, fn)
      end
    end

    def done
      [].tap do |oks|
        git("show-branch --list bt/#{@head.id}/*").each_line do |branch_line|
          %r{ \[bt/(?<hash>[0-9a-f]+)/(?<stage>\w+)\] (?<status>OK|PASS|FAIL|NO) } =~ branch_line
          oks << stage if ['OK', 'PASS'].include? status
        end
      end.map { |s| Stage.new @head, "stages/#{s}" }
    end

    def incomplete
      stages - done
    end
  end
end
