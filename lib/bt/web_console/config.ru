$LOAD_PATH.unshift File.expand_path('../../', File.dirname(__FILE__))

require 'bt/web_console/app'

run BT::WebConsole::App
