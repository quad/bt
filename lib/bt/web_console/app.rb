require 'sinatra/base'
require 'bt'
require 'haml'
require 'bt/web_console/models'

ENV['REPOSITORY'] ||= Dir.pwd

module BT
  module WebConsole
    class App < Sinatra::Base
      set :views, proc { File.join(File.dirname(__FILE__), 'views') }

      configure :production do
        set :raise_errors, false
        set :show_exceptions, false
      end

      #TODO: Using BT::* models, should probably be using a bt-results variant
      get '/' do
        r = Repository.new(ENV['REPOSITORY'])
        haml :index, :locals => {:commits => r.commits(:max_results => 10) }
      end

      get '/commits/:label/results' do
        result = Result.new ENV['REPOSITORY'], params[:label]
        responder do |r|
           r.text { result.as_text }
           r.json { result.as_json }
        end
      end

      get '/commits/:label/pipeline' do
        pipeline = Pipeline.new ENV['REPOSITORY'], params[:label]
        responder do |r|
          r.text { pipeline.as_yaml }
          r.json { pipeline.as_json }
        end
      end

      error BT::WebConsole::BadReference do
        404
      end

      def responder &block
        Responder.new self, &block
      end
    end

    class Responder
      def initialize app, &block
        @app = app
        @responses = []
        yield self
        respond
      end

      def json &block
        map_content_types 'application/json', 'application/*', '*/*', &block
      end

      def text &block
        map_content_types 'text/plain', 'text/*', '*/*', &block
      end

      def map_content_types *content_types, &block
        content_types.each { |content_type| @responses << {:content_type => content_type, :content_proc => block} }
      end

      def respond
        response = @responses.detect { |response| @app.request.accept.include? response[:content_type] } 
        @app.content_type response[:content_type]
        @app.body response[:content_proc].call
      end
    end
  end
end
