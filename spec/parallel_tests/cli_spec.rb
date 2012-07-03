require 'spec_helper'
require 'parallel_tests/cli'

describe ParallelTest::CLI do
  describe ".parse_options" do
    let(:defaults){ {:files => []} }

    def call(*args)
      ParallelTest::CLI.send(:parse_options!, *args)
    end

    it "parses regular count" do
      call(["-n3"]).should == defaults.merge(:count => 3)
    end

    it "parses count 0 as non-parallel" do
      call(["-n0"]).should == defaults.merge(:non_parallel => true)
    end

    it "parses non-parallel as non-parallel" do
      call(["--non-parallel"]).should == defaults.merge(:non_parallel => true)
    end
  end
end
