module BT
  require 'andand'
  require 'forwardable'
  require 'yaml'

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

    private
    def merge!(hash)
      hash.each_pair { |k, v| self[k] = v }
    end
  end

  class Repository < Struct.new(:path)
    def initialize(path)
      super(path)
      @head = Commit.new self, 'HEAD'
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

    def git(cmd)
      Dir.chdir(path) { `git #{cmd}` }
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
