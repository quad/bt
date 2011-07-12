require 'bt/web_console/models/reference'

module BT
  module WebConsole
    class Result
      def initialize repository_dir, label
        @repository_dir = repository_dir
        @reference = Reference.new(label)
      end

      def as_json
        `bt-results --commit #{@reference} --format json "#{@repository_dir}"`
      end

      def as_text
        `bt-results --commit #{@reference} --format text "#{@repository_dir}"`
      end
    end
  end
end
