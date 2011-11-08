module BT
  require 'bt/yaml'
  require 'andand'

  class Command < Struct.new :command
    def initialize command, silent = false 
      super(command)
      @silent = silent
    end

    def execute
      result = ''
      IO.popen(['sh', '-c', self[:command], :err => [:child, :out]]) do |io|
        begin
          while c = io.readpartial(4096)
            result << c
            $stdout << c unless @silent
          end
        rescue EOFError
        end
      end
      [$?.exitstatus, result]
    end
  end

  class Stage < Struct.new(:commit, :name, :specification, :needs, :run, :results)

    MSG = 'bt loves you'

    def initialize(commit, name, specification)
      super(commit, name, specification, [], nil, [])
      merge! specification
      @run = Command.new self[:run]
    end

    def passed?
      result.andand { |r| r.message.start_with?('PASS') }
    end

    def failed?
      result.andand { |r| r.message.start_with?('FAIL') }
    end

    def done?
      result
    end

    def build
      commit.workspace(needs.map(&:result)) do
        status, log = @run.execute

        files = results.select {|fn| File.readable? fn}
        flag = (files == results) && status.zero?
        message = "#{flag ? :PASS : :FAIL} #{MSG}\n\n#{log}"

        [name, message, files]
      end
    end

    def result
      commit.result name
    end

    def blockers
      needs.reject(&:passed?)
    end

    def ready?
      needs.all?(&:passed?) && !done?
    end

    def to_hash
      result_hash = result ? result.to_hash : {}
      {name => result_hash}
    end

    def to_s
      "#{commit.sha}/#{name}"
    end

    private

    def merge!(hash)
      hash.each_pair { |k, v| self[k] = v }
    end
  end
end
