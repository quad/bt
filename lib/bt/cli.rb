module BT
  module Cli
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

      Grit.debug = true if opts[:debug]

      yield Repository.new ARGV.shift || Dir.pwd
    end

    def bin_path
      begin
        Gem.bin_path BT::NAME
      rescue Gem::GemNotFoundException
        begin
          require 'bundler'
          begin
            Bundler.bin_path
          rescue Bundler::GemfileNotFound
            raise LoadError
          end
        rescue LoadError
          File.expand_path('../../../bin/', __FILE__)
        end
      end
    end

    def find_command name
      File.join bin_path, "bt-#{name}"
    end
  end
end
