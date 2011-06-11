module BT
  require 'forwardable'
  require 'grit'
  require 'tmpdir'
  require 'yaml'

  MSG = 'bt loves you'

  class Stage < Struct.new(:pipeline, :name, :specification, :needs, :run, :results)
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

    def ok?
      ['OK', 'PASS'].any? { |status| ref.commit.message.start_with? status } if ref
    end

    def initialize(pipeline, name, specification)
      super(pipeline, name, specification, [], nil, [])
      merge! specification
    end

    def needs
      pipeline.stages.select { |s| self[:needs].include? s.name }
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

    def ready_in? pipeline
      (needs - pipeline.done).empty?
    end

    private

    # TODO: Kill
    def commit
      pipeline.commit
    end

    # TODO: Kill
    def repo
      commit.repository.repo
    end

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

  class Pipeline < Struct.new :commit
    def ready
      incomplete.select { |stage| stage.ready_in? self }
    end

    def stages
      (commit.tree / 'stages').blobs.map do |stage_blob|
        Stage.new self, stage_blob.basename, YAML::load(stage_blob.data)
      end
    end

    def done
      stages.select { |s| s.ok? }
    end

    def incomplete
      stages - done
    end
  end
end
