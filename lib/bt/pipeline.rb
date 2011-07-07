require 'bt/stage'
require 'set'

module BT
  class Pipeline < Struct.new(:commit, :stage_definition)
    def stages
      stage_definition = self[:stage_definition].dup
      Set.new.tap do |known_stages|
        while !stage_definition.empty?
          name, definition = next_satisfied! stage_definition, known_stages
          needs = definition['needs'].map do |name|
            known_stages.detect { |s| s.name == name }
          end
          known_stages << BT::Stage.new(commit, name, definition.merge('needs' => needs))
        end
      end
    end

    def ready
      stages.select(&:ready?)
    end

    def to_hash
      {commit.sha => stages.inject({}) {|result, stage| result.merge(stage.to_hash)}}
    end

    private

    def next_satisfied! stage_definition, known_stages
      stage = stage_definition.detect do |name, definition|
        definition['needs'].all? {|n| known_stages.map(&:name).include? n}
      end
      stage_definition.delete(stage[0])
      stage
    end
  end
end


