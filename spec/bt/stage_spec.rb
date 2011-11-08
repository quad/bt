require 'bt'

include BT

describe "a stage with no needs" do
  let(:commit) { mock(:commit, :result => nil) }

  subject { Stage.new commit, 'first', {'run' => 'exit 0', 'results' => [], 'needs' => []} }

  it { should be_ready }

  context "with a result" do
    let(:result) { mock(:result, :message => message) }

    before { commit.stub(:result).and_return(result) }

   context "which was a pass" do
      let(:message) { 'PASS bt loves you' }

      it { should be_done }
      it { should be_passed }
    end

    context "which was a fail" do
      let(:message) { 'FAIL bt loves you' }

      it { should be_done }
      it { should_not be_passed }
    end
  end

  context "without a result" do
    it { should_not be_done }
  end
end

describe "an incomplete stage" do
  let(:commit) { mock(:commit, :result => nil) }

  subject do
    Stage.new commit, 'first', {
      'run' => '',
      'results' => [],
      'needs' => needs
    }
  end

  context "with satisfied needs" do
    let(:needs) { [mock(:stage, :passed? => true), mock(:stage, :passed? => true)] }

    it { should be_ready }
  end

  context "with unsatisfied needs" do
    let(:needs) { [mock(:stage, :passed? => true), mock(:stage, :passed? => false)] }

    it { should_not be_ready }
  end
end

