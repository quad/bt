require 'sinatra/base'
require 'bt'
require 'haml'
require 'bt/web_console/models'

module BT
  module WebConsole
    class App < Sinatra::Base
      set :views, proc { File.join(File.dirname(__FILE__), 'views') }

      get '/' do
        r = Repository.new(ENV['REPOSITORY'])
        haml :index, :locals => {:commits => r.commits(:max_results => 10) }
      end

      get '/commits/:label' do
        result = Result.all(params[:label])
        stages = Stage.all(params[:label])
        haml :commit, :locals => {:result => result, :stages => stages}
      end
    end
  end
end
