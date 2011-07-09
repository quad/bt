require 'bt/web_console/models/reference'

module BT
  module WebConsole
    class Result
      def initialize repository_dir, label
        @repository_dir = repository_dir
        @reference = Reference.new(label)
        @reference.valid? or raise BadReference
      end

      def as_json
        `bt-results --commit #{@reference} --format json "#{@repository_dir}"`
      end

      def as_human
        `bt-results --commit #{@reference} --format human "#{@repository_dir}"`
      end
    end
  end
end
