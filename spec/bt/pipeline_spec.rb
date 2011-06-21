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

  context "with a definition with two unordered stages" do
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
end

RSpec::Matchers.define :include_only do |*items|
  match do |collection|
    (collection.to_a & items) == items
  end
end
