module BT
  module Cli
    require 'trollop'

    def single_repo_cmd(command, help, &block)
      opts = Trollop::options do
        opt :debug, "Debugging text scrolls"
        banner <<-EOS
        #{help}

Usage:
\tbt-#{command} [repository]
        EOS
      end

      Grit.debug = true if opts[:debug]

      yield Repository.new ARGV.shift || Dir.pwd
    end
  end
end
