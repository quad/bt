require 'bt/stage'
require 'set'

module BT
  class Pipeline < Struct.new(:commit, :stage_definition)
    def walk &block
      topo_sorted_stages = stages
      while (stage = topo_sorted_stages.shift)
        block.call stage
      end
    end

    def stages
      unknown_stages = self[:stage_definition].dup
      Array.new.tap do |known_stages|
        while !unknown_stages.empty?
          name, definition = next_satisfied! unknown_stages, known_stages

          # Find all of the needs for this stage. They're already guaranteed to
          # be amongst the known stages since the stage we selected must have
          # had all of its requirements satisfied.
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

    def status
      return 'FAIL' if stages.any?(&:failed?)
      return 'PASS' if stages.all?(&:passed?)
      return 'INCOMPLETE' if stages.any?(&:passed?)
      'UNKNOWN'
    end

    private

    def next_satisfied! unknown_stages, known_stages
      # Find the first stage for whom all dependencies have been satisfied. 
      stage = unknown_stages.detect do |name, definition|
        definition['needs'].all? {|n| known_stages.map(&:name).include? n}
      end

      unknown_stages.delete(stage[0])
      stage
    end
  end
end


