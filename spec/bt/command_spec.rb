require 'bt'

describe BT::Command do
  subject { BT::Command.new(command, true).execute }

  describe "echo blah" do
    let(:command) { "echo \"blah\"" }

    its(:first) { should == 0 }
    its(:last) { should == "blah\n" }
  end

  describe "injection command" do
    let(:command) { "echo \"$(pwd)\"" }

    its(:last) { should == `pwd` }
  end

  describe "spaced out" do
    let(:command) { "  echo     \"stuff\n\"       \n" }

    its(:last) { should == "stuff\n\n" }
  end

  describe "extra quote" do
    let(:command) { "  echo     \"stuff\n\"\"       \n" }

    its(:first) { should_not == 0 }
  end
end
