module BT
  module WebConsole
    class BadReference < Exception
    end

    class Reference < Struct.new :name
      def valid?
        name =~ /[a-f0-9]{40}/ or name == 'HEAD'
      end

      def to_s
        name
      end
    end
  end
end
