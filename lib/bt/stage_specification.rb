require 'bt/yaml'

module BT
  class GeneratedSpecification < Struct.new :file
    def to_hash
      YAML.load(`#{file}`)
    end
  end

  class StaticSpecification < Struct.new :file
    def to_hash
      yaml = YAML.load(File.open(file).read)
      {File.basename(file) => {'needs' => [], 'results' => [], 'run' => ''}.merge(yaml)}
    end
  end

  class StageSpecification < Struct.new :files
    def to_hash
      files.map do |f|
        File.executable?(f) ? GeneratedSpecification.new(f) : StaticSpecification.new(f)
      end.inject({}) do |result, stage_spec|
        result.merge stage_spec.to_hash
      end
    end
  end
end


