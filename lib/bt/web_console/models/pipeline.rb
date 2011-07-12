require 'bt/web_console/models/reference'

module BT
  module WebConsole
    class Pipeline
      def initialize repository_dir, label
        @repository_dir = repository_dir
        @reference = Reference.new label
      end

      def as_json
        `bt-stages --commit #{@reference} --format json "#{@repository_dir}"`
      end

      def as_yaml
        `bt-stages --commit #{@reference} --format yaml "#{@repository_dir}"`
      end
    end
  end
end
