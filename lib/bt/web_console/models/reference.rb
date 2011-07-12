module BT
  module WebConsole
    class BadReference < Exception
    end

    class Reference < Struct.new :name
      def initialize name
        super(name)
        raise BadReference unless valid?
      end

      def to_s
        name
      end

      private

      def valid?
        name =~ /[a-f0-9]{40}/ or name == 'HEAD'
      end
    end
  end
end
