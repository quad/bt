module BT
  module WebConsole
    class Stage
      def self.all label
        `bt-stages --commit #{label}`
      end
    end
  end
end
