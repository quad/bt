module BT
  require 'andand'
  require 'forwardable'
  require 'yaml'
  require 'tmpdir'

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
          log = `#{run} 2>&1`
          status = $?.exitstatus.zero? ? :PASS : :FAIL

          # Commit results
          results.each { |fn| r.git "add #{fn}" }
          r.git "commit --allow-empty --cleanup=verbatim --file=-" do |pipe|
            pipe.puts "#{status.to_s} bt loves you"
            pipe.puts

            pipe << log
            pipe.close_write
          end
        end

        # Merge back
        repository.git "fetch #{tmp_dir} HEAD:#{branch_name}", :system
      end
    end

    def lead(&block)
      raise NotImplementedError

      # mDNS magic goes here.
      # Spawn a thread to keep the record refreshed.
      yield if block_given?
      # Cleanup that thread.
    end

    private
    def merge!(hash)
      hash.each_pair { |k, v| self[k] = v }
    end
  end

  class Repository < Struct.new(:path)
    def initialize(path, &block)
      super(path)
      @head = Commit.new self, 'HEAD'
      Dir.chdir(path) { yield self } if block_given?
    end

    def ready
      dones = done

      # TODO: This could probably be expressed nicer.
      [].tap do |readies|
        (stages - dones).each do |stage|
          needs = stage.needs - dones
          readies << stage if needs.empty?
        end
      end - dones
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

    def bare
      raise NotImplementedError
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
  end
end
