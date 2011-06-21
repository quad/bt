require 'bt/stage'

module BT
  class Pipeline < Struct.new(:commit, :stage_definition)
    def stages
      stage_definition.map do |name, definition|
        BT::Stage.new commit, name, definition
      end
    end

    def ready
      stages.select(&:ready?)
    end
  end
end


