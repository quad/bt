module BT
  module WebConsole
    class Result
      def self.as_json label
        `bt-results --commit #{label} --format json`
      end

      def self.as_human label
        `bt-results --commit #{label} --format human`
      end
    end
  end
end
