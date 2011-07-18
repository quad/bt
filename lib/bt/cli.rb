require 'grit'

module BT
  module Cli
    Grit.logger = Logger.new($stderr)
    Grit.debug = true if ENV['DEBUG']

    require 'trollop'

    def single_repo_cmd(command, help, &block)
      opts = Trollop::options do
        banner <<-EOS
#{help}

Usage:
\tbt-#{command} [repository]
        EOS
        opt :debug, "Debugging text scrolls"
      end

      yield Repository.new ARGV.shift || Dir.pwd
    end

    def find_command name
      "bt-#{name}"
    end
  end
end
