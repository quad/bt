require 'eventmachine'
require 'bt/cli'
require 'andand'

class Ready
  include BT::Cli

  def initialize repository, &callback
    @callback = callback
    @readies = []
    @nones = []
    @repository = repository
  end

  def next
    callback = @callback
    refresh do |readies|
      if readies.empty?
        @nones.each { |n| n.call }
      else
        next_ready = readies.shuffle.shift
        @callback.call next_ready[:commit], next_ready[:stage]
      end
    end
  end

  def none &block
    @nones << block
  end

  def refresh &callback
    EM.popen("#{find_command :ready} \"#{@repository}\"", Process, callback)
  end

  class Process < EM::Connection
    def initialize callback
      @callback = callback
      @readies = []
    end

    def receive_data data
      (@buffer ||= BufferedTokenizer.new).extract(data).each do |line|
        commit, stage = line.split '/'
        @readies << {:commit => commit, :stage => stage}
      end
    end

    def unbind
      @callback.call @readies
    end
  end
end

class Go
  include BT::Cli

  def initialize repository, commit, stage
    @repository = repository
    @commit = commit
    @stage = stage
    @done = EM::DefaultDeferrable.new
    @line_callbacks = []
  end

  def done &block
    @done.callback &block
  end

  def line &block
    @line_callbacks << block
  end

  def build
    @connection = EM.popen("#{find_command :go} --commit #{@commit} --stage #{@stage} --directory \"#{@repository}\"", Process, @done, @line_callbacks)
  end

  def stop
    @connection.andand.close_connection
  end

  class Process < EM::Connection
    def initialize done, line_callbacks
      @done = done
      @line_callbacks = line_callbacks
    end

   def receive_data data
     (@buffer ||= BufferedTokenizer.new).extract(data).each do |line|
       @line_callbacks.each { |c| c.call line }
     end
   end

    def unbind
      @done.succeed
    end
  end
end

class Agent
  include BT::Cli

  def initialize key
    @stop = EM::DefaultDeferrable.new
    @lead = EM::DefaultDeferrable.new
    @connection = EM.popen("#{find_command :agent} #{key}", Process, @stop, @lead)
  end

  def leading &block
    @lead.callback &block
  end

  def stop
    @connection.close_connection
  end

  def stopped &block
    @stop.callback &block
  end

  class Process < EM::Connection
    def initialize stop, lead
      @stop = stop
      @lead = lead
    end

    def receive_data data
      @lead.succeed
    end

    def unbind
      @stop.succeed
    end
  end
end


