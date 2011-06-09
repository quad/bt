module BT
  require 'andand'
  require 'dnssd'
  require 'forwardable'
  require 'tempfile'
  require 'tmpdir'
  require 'yaml'
  require 'grit'

  MSG = 'bt loves you'
  
  class Commit < Struct.new(:repository, :name, :id)
    extend Forwardable

    def initialize(repository, name)
      id = repository.git.rev_parse({:verify => true}, name).chomp
      super(repository, name, id)
    end
  end

  class Stage < Struct.new(:commit, :filename, :needs, :run, :results)
    extend Forwardable

    def_delegator :commit, :repository

    def initialize(commit, filename)
      super(commit, filename, [], nil, [])
      merge! YAML::load repository.cat_file(commit.id, filename)
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
        repository.git.clone({:recursive => true}, repository.path, tmp_dir)

        Repository.new(tmp_dir) do |r|
          # Merge
          needs.each do |n|
            r.git.pull({:raise => true, :squash => true}, 'origin', n.branch_name)
          end

          r.git.reset({:raise => true, :mixed => true}, commit.id)

          # Build
          status, log = run

          # Commit results
          message = "#{status.zero? ? :PASS : :FAIL} #{MSG}\n\n#{log}"
          r.commit message, results
        end

        # Merge back
        repository.git.fetch({:raise => true}, tmp_dir, "HEAD:#{branch_name}")
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
      Tempfile.open("bt-#{commit.id}-#{name}.log") do |f|
        system "( #{self[:run]} ) | tee '#{f.path}'"
        [$?.exitstatus, f.read]
      end
    end
  end

  class Repository < Struct.new(:path)
    
    def self.bare(path, &block)
      Dir.mktmpdir do |tmp_dir|
        repo = Grit::Repo.new(path)
        tmp_repo = repo.git.clone({:mirror => true}, path, tmp_dir)
        Grit::Repo.init_bare(tmp_dir) #This will throw exceptions if the repo is bad
        yield new tmp_dir
      end
    end

    def initialize(path, &block)
      super(path)
      @repo = Grit::Repo.new(path)
      
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

    private
    def stages
      (@repo.tree(@head.id) / 'stages').blobs.map do |stage_blob|
        Stage.new(@head, "stages/#{stage_blob.basename}")
      end
    end

    def done
      stages.select do |stage|
        stage_branch = @repo.get_head(stage.branch_name)
        if stage_branch
          ['OK', 'PASS'].any? {|status| stage_branch.commit.message.start_with? status}
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
