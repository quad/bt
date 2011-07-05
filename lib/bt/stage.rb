module BT
  require 'bt/yaml'

  class Stage < Struct.new(:commit, :name, :specification, :needs, :run, :results)

    MSG = 'bt loves you'

    def initialize(commit, name, specification)
      super(commit, name, specification, [], nil, [])
      merge! specification
    end

    def ok?
      (r = result) && r.message.start_with?('PASS')
    end

    def done?
      result
    end

    def build
      commit.workspace(needs.map(&:result)) do
        status, log = run

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
end
