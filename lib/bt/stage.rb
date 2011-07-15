module BT
  require 'bt/yaml'
  require 'open3'

  class Command < Struct.new :command
    def initialize command, opts = {}
      super(command)
      @opts = {:out => $stdout}.merge(opts)
      if opts[:silent]
        @opts[:out] = IO.pipe[1]
      end
    end

    def execute
      result = ''
      exitstatus = nil
      Open3.popen2e('sh -') do |input, output, wait_thread|
        input << self[:command]
        input.close_write

        begin
          while c = output.readpartial(4096)
            [result, @opts[:out]].each {|o| o << c}
          end
        rescue EOFError
        end

        exitstatus = wait_thread.value.exitstatus
      end
      [exitstatus, result]
    end
  end

  class Stage < Struct.new(:commit, :name, :specification, :needs, :run, :results)

    MSG = 'bt loves you'

    def initialize(commit, name, specification)
      super(commit, name, specification, [], nil, [])
      merge! specification
      @run = Command.new self[:run]
    end

    def ok?
      (r = result) && r.message.start_with?('PASS')
    end

    def fail?
      (r = result) && r.message.start_with?('FAIL')
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

    def ready?
      needs.all?(&:ok?) && !done?
    end

    def to_hash
      result_hash = result ? result.to_hash : {}
      {name => result_hash}
    end

    private

    def merge!(hash)
      hash.each_pair { |k, v| self[k] = v }
    end
  end
end
