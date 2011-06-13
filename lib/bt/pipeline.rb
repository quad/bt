module BT
  require 'yaml'

  class Stage < Struct.new(:pipeline, :name, :specification, :needs, :run, :results)
    def ok?
      (r = result) && r.message.start_with?('PASS')
    end

    def done?
      result
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
      result = ''
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
    MSG = 'bt loves you'

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
      stages.select { |s| s.done? }
    end

    def incomplete
      stages - done
    end

    def build stage
      commit.workspace(stage.needs.map(&:result)) do
        status, log = stage.run

        files = stage.results.select {|fn| File.readable? fn}
        flag = (files == stage.results) && status.zero?
        message = "#{flag ? :PASS : :FAIL} #{MSG}\n\n#{log}"

        [stage.name, message, files]
      end
    end
  end
end
