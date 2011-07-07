module BT
  module WebConsole
    class Result
      def self.all label
        `bt-results --commit #{label}`
      end
    end
  end
end
