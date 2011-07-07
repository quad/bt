require 'sinatra/base'
require 'bt'
require 'haml'

module BT
  module WebConsole
    class App < Sinatra::Base
      set :views, proc { File.join(File.dirname(__FILE__), 'views') }

      get '/' do
        r = Repository.new(ENV['REPOSITORY'])
        haml :index, :locals => {:commits => r.commits(:max_results => 10) }
      end

      get '/commits/:sha' do
        result = `bt-results --commit #{params[:sha]}`
        stages = `bt-stages --commit #{params[:sha]}`
        haml :commit, :locals => {:result => result, :stages => stages}
      end
    end
  end
end
