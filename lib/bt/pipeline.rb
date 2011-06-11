module BT
  require 'tmpdir'
  require 'yaml'

  MSG = 'bt loves you'

  class Stage < Struct.new(:pipeline, :name, :specification, :needs, :run, :results)
    def ok?
      (r = result) && ['OK', 'PASS'].any? { |status| r.message.start_with? status }
    end

    def initialize(pipeline, name, specification)
      super(pipeline, name, specification, [], nil, [])
      merge! specification
    end

    def needs
      pipeline.stages.select { |s| self[:needs].include? s.name }
    end

    def build
      pipeline.build self
    end

    def result
      pipeline.result self
    end

    def ready?
      (needs - pipeline.done).empty?
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

    private

    def merge!(hash)
      hash.each_pair { |k, v| self[k] = v }
    end
  end

  class Pipeline < Struct.new :commit
    def result stage
      commit.result stage.name
    end

    def ready
      incomplete.select { |stage| stage.ready? }
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

    def build stage
      status = nil

      # TODO: Log the whole build transaction.
      Dir.mktmpdir do |tmp_dir|
        repo.git.clone({:recursive => true}, repo.path, tmp_dir)

        Repository.new(tmp_dir) do |r|
          stage.needs.each { |n| r.merge n.result }

          r.git.reset({:raise => true, :mixed => true}, commit.sha)

          # Build
          status, log = stage.run

          # Commit results
          message = "#{status.zero? ? :PASS : :FAIL} #{MSG}\n\n#{log}"
          r.commit message, stage.results
        end

        # Merge back
        repo.git.fetch({:raise => true}, tmp_dir, "+HEAD:#{branch_name stage}")
      end

      status
    end

    def branch_name stage
      "refs/bt/#{stage.name}/#{commit.sha}"
    end

    # TODO: Kill
    def repo
      commit.repository.repo
    end
  end
end
