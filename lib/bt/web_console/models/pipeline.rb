require 'bt/web_console/models/reference'

module BT
  module WebConsole
    class Pipeline
      def initialize label
        @reference = Reference.new label
        @reference.valid? or raise BadReference
      end

      def as_json
        `bt-stages --commit #{@reference} --format json`
      end

      def as_human
        `bt-stages --commit #{@reference} --format yaml`
      end
    end
  end
end
