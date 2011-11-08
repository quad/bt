require 'bt'
require 'bt/yaml'

describe BT::Pipeline do
  context "with a definition comprising one stage" do
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

  context "with a definition comprising two stages" do
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

  context "with a definition comprising two out of order stages" do
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

  context "with a diamond dependency" do
    let(:commit) { mock(:commit) }
    let(:definition) do
      <<-EOS
---
first:
  needs: []
  results: []
  run: exit 0

secondA:
  needs:
  - first
  results: []
  run: exit 0

secondB:
  needs:
  - first
  results: []
  run: exit 0

third:
  needs:
  - secondA
  - secondB
  results: []
  run: exit 0
      EOS
    end

    let(:pipeline) { BT::Pipeline.new commit, YAML.load(definition) }

    subject { pipeline }

    let(:first) { BT::Stage.new(commit, 'first', {'needs' => [], 'results' => [], 'run' => 'exit 0'}) }
    let(:secondA) { BT::Stage.new(commit, 'secondA', {'needs' => [first], 'results' => [], 'run' => 'exit 0'}) }
    let(:secondB) { BT::Stage.new(commit, 'secondB', {'needs' => [first], 'results' => [], 'run' => 'exit 0'}) }
    let(:third) { BT::Stage.new(commit, 'third', {'needs' => [secondA, secondB], 'results' => [], 'run' => 'exit 0'}) }

    describe 'third stage' do
      subject { pipeline.stages.detect { |s| s.name == 'third' } }
      its(:needs) { should == [secondA, secondB] }
    end

    context "all stages have passed" do
      before do
        commit.stub(:result).and_return(mock(:commit, :message => 'PASS bt loves you'))
      end

      its(:status) { should == 'PASS' }
    end

    context "one of the second stages fails and the other passes" do
      before do
        commit.stub(:result).and_return(nil)
        commit.stub(:result).with('secondA').and_return(mock(:commit, :message => 'FAIL bt loves you'))
      end

      its(:status) { should == "FAIL" }
    end
  end

  context "with a definition comprising three out of order stages" do
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

    context "all stages have passed" do
      before do
        commit.stub(:result).and_return(mock(:commit, :message => 'PASS bt loves you'))
      end

      its(:status) { should == 'PASS' }
    end

    context "second stage failed" do
      before do
        commit.stub(:result).and_return(nil)
        commit.stub(:result).with('second').and_return(mock(:commit, :message => 'FAIL bt loves you'))
      end

      its(:status) { should == 'FAIL' }
    end

    context "stages not failed nor all passed" do
      before { commit.stub(:result).and_return(nil) }

      its(:status) { should == 'UNKNOWN' }
    end

    context "no stages failed and some passed" do
      before do
        commit.stub(:result).and_return(nil)
        commit.stub(:result).with("first").and_return(mock(:commit, :message => 'PASS bt loves you'))
      end

      its(:status) { should == 'INCOMPLETE' }
    end
  end
end

RSpec::Matchers.define :include_only do |*items|
  match do |collection|
    (collection.to_a & items) == items
  end
end
