require 'bt/stage'
require 'set'

module BT
  class Pipeline < Struct.new(:commit, :stage_definition)
    def stages
      known_stages = Set.new
      sort_by_needs(stage_definition).map do |name, definition|
        needs = definition['needs'].map do |name|
          known_stages.detect { |s| s.name == name }
        end
        known_stages << BT::Stage.new(commit, name, definition.merge('needs' => needs))
      end

      known_stages
    end

    def ready
      stages.select(&:ready?)
    end

    private

    def sort_by_needs definition
      definition.sort {|a, b| a[1]['needs'].size <=> b[1]['needs'].size}
    end
  end
end


