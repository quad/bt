module BT
  require 'andand'
  require 'yaml'

  class Stage < Hash
    # TODO: Comparison operators. (Taking into account commit + filename?)
    # TODO: A more informative to_s.
    
    def initialize(commit, filename)
      @commit = commit
      @filename = filename
      merge!(YAML::load `git cat-file blob #{commit}:#{filename}`)
    end

    def name
      File.basename(@filename)
    end

    def needs
      (self['needs'] || []).map do |stage_name|
        Stage.new @commit, File.join(File.dirname(@filename), stage_name)
      end
    end

    [:run, :results].each { |n| define_method(n) { self[n.to_s] } }
  end

  class Repository
    def initialize(path)
      @path = path
      # TODO: Do something with the path.
      @head = commit 'HEAD'
    end

    def ready
      dones = done

      [].tap do |readies|
        (stages - dones).each do |stage|
          needs = stage.needs - dones
          readies << stage if needs.empty?
        end
      end - dones
    end

    private
    def commit(name)
      `git rev-parse --verify #{name}`.strip
    end

    def stages
      `git ls-tree --name-only #{@head} stages/`.split.map do |fn|
        Stage.new(@head, fn)
      end
    end

    def done
      [].tap do |oks|
        `git show-branch --list bt/#{commit 'HEAD'}/*`.each_line do |branch_line|
          %r{ \[bt/(?<hash>[0-9a-f]+)/(?<stage>\w+)\] (?<status>OK|PASS|FAIL|NO) } =~ branch_line
          oks << stage if ['OK', 'PASS'].include? status
        end
      end.map { |s| Stage.new @head, s }
    end
  end
end
