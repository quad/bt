require 'bt'
require 'yaml'

describe BT::Pipeline do
  context "with a definition with one stage" do
    let(:commit) { mock(:commit) }
    let(:definition) do
      <<-EOS
---
first:
  needs: []

  results: []

  run: exit 0
      EOS
    end

    subject { BT::Pipeline.new commit, YAML.load(definition) }

    its(:stages) { should include_only BT::Stage.new(commit, 'first', {'run' => 'exit 0', 'results' => [], 'needs' => []}) }
  end

  context "with a definition with two stages" do
    let(:commit) { mock(:commit) }
    let(:definition) do
      <<-EOS
---
first:
  needs: []

  results: []

  run: exit 0
second:
  needs:
  - first
  results: []

  run: exit 0
      EOS
    end

    subject { BT::Pipeline.new commit, YAML.load(definition) }

    its(:stages) do
      first = BT::Stage.new(commit, 'first', {'needs' => [], 'results' => [], 'run' => 'exit 0'})
      should include_only first, BT::Stage.new(commit, 'second', {'run' => 'exit 0', 'results' => [], 'needs' => [first]})
    end
  end

  context "with a definition with two out of order stages" do
    let(:commit) { mock(:commit) }
    let(:definition) do
      <<-EOS
---
second:
  needs:
  - first
  results: []

  run: exit 0
first:
  needs: []

  results: []

  run: exit 0
     EOS
    end

    subject { BT::Pipeline.new commit, YAML.load(definition) }

    its(:stages) do
      first = BT::Stage.new(commit, 'first', {'needs' => [], 'results' => [], 'run' => 'exit 0'})
      should include_only first, BT::Stage.new(commit, 'second', {'run' => 'exit 0', 'results' => [], 'needs' => [first]})
    end
  end 

  context "with a definition with three out of order stages" do
    let(:commit) { mock(:commit) }
    let(:definition) do
      <<-EOS
---
third:
  needs: []

  results: []

  run: exit 0
second:
  needs:
  - first
  results: []

  run: exit 0
first:
  needs:
  - third
  results: []

  run: exit 0
     EOS
    end

    let(:pipeline) { BT::Pipeline.new commit, YAML.load(definition) }

    subject { pipeline }

    let(:first) { BT::Stage.new(commit, 'first', {'needs' => [third], 'results' => [], 'run' => 'exit 0'}) }
    let(:second) { BT::Stage.new(commit, 'second', {'needs' => [first], 'results' => [], 'run' => 'exit 0'}) }
    let(:third) { BT::Stage.new(commit, 'third', {'needs' => [], 'results' => [], 'run' => 'exit 0'}) }

    describe 'first stage' do
      subject { pipeline.stages.detect {|s| s.name == 'first' } }

      it { should have(1).needs }

      its(:needs) { should == [third] }
    end

    describe 'second stage' do
      subject { pipeline.stages.detect {|s| s.name == 'second' } }

      it { should have(1).needs }

      its(:needs) { should == [first] }
    end

    describe 'third stage' do
      subject { pipeline.stages.detect {|s| s.name == 'third' } }

      it { should have(0).needs }
    end
  end
end

RSpec::Matchers.define :include_only do |*items|
  match do |collection|
    (collection.to_a & items) == items
  end
end
