module BT
  require 'yaml'

  class Repository
    def ready
      dones = done

      [].tap do |readies|
        stages.each do |name, info|
          needs = info['needs'] ? info['needs'] - dones : []
          readies << name if needs.empty?
        end
      end - dones
    end

    private
    def stages
      # TODO: Enforce stages being politely named.
      Hash[`git ls-tree --name-only HEAD stages/`.split.map do |fn|
        [File.basename(fn), YAML.load(`git cat-file blob HEAD:#{fn}`)]
      end]
    end

    def commit(name)
      `git rev-parse --verify #{name}`.strip
    end

    def done
      [].tap do |oks|
        `git show-branch --list bt/#{commit 'HEAD'}/*`.each_line do |branch_line|
          %r{ \[bt/(?<hash>[0-9a-f]+)/(?<stage>\w+)\] (?<status>OK|PASS|FAIL|NO) } =~ branch_line
          oks << stage if ['OK', 'PASS'].include? status
        end
      end
    end
  end
end
