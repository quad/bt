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

      get '/commits/:label/results' do
        if request.accept.include? 'application/json'
          content_type :json
          Result.as_json(params[:label])
        else
          content_type :text
          Result.as_human(params[:label])
        end
      end

      get '/commits/:label/stages' do
        if request.accept.include? 'application/json'
          content_type :json
          Stage.as_json(params[:label])
        else
          content_type :text
          Stage.as_human(params[:label])
        end
      end
    end
  end
end
