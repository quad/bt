module FileBuilder
  def self.included base
    base.extend ClassMethods
  end

  module ClassMethods
    def temporary_file name, &block
      let(name.to_sym) do
        f = FileBuilder::Tempfile.new &block
        f.build
      end
    end

    def executable_file name, &block
      temporary_file name do |f|
        f.executable
        block.call f
      end
    end
  end

  class Tempfile
    def initialize &block
      @mode = 0644
      @content = ''
      yield self
    end

    def executable
      @mode = 0777
    end

    def content c
      @content = c
    end

    def build
      f = ::Tempfile.new('')
      f.write @content
      f.close
      File.chmod(@mode, f.path)
      f
    end
  end
end
