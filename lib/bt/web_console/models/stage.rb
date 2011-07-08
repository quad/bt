module BT
  module WebConsole
    class Stage
      def self.as_json label
        `bt-stages --commit #{label} --format json`
      end

      def self.as_human label
        `bt-stages --commit #{label} --format yaml`
      end
    end
  end
end
