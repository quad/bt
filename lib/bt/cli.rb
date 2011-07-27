require 'grit'

module BT
  module Cli
    Grit.logger = Logger.new($stderr)
    Grit.debug = true if ENV['DEBUG']

    require 'trollop'

    def find_command name
      "bt-#{name}"
    end
  end
end
