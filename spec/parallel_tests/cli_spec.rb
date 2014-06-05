require "spec_helper"
require "parallel_tests/cli"
require "parallel_tests/rspec/runner"


describe ParallelTests::CLI do
  subject { ParallelTests::CLI.new }

  describe "#parse_options" do
    let(:defaults){ {:files => []} }

    def call(*args)
      subject.send(:parse_options!, *args)
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

    it "finds the correct type when multiple are given" do
      call(["--type", "test", "-t", "rspec"])
      subject.instance_variable_get(:@runner).should == ParallelTests::RSpec::Runner
    end

    it "parses nice as nice" do
      call(["--nice"]).should == defaults.merge(:nice => true)
    end
  end

  describe "#load_runner" do
    it "requires and loads default runner" do
      subject.should_receive(:require).with("parallel_tests/test/runner")
      subject.send(:load_runner, "test").should == ParallelTests::Test::Runner
    end

    it "requires and loads rspec runner" do
      subject.should_receive(:require).with("parallel_tests/rspec/runner")
      subject.send(:load_runner, "rspec").should == ParallelTests::RSpec::Runner
    end

    it "requires and loads runner with underscores" do
      subject.should_receive(:require).with("parallel_tests/my_test_runner/runner")
      subject.send(:load_runner, "my_test_runner").should == ParallelTests::MyTestRunner::Runner
    end

    it "fails to load unfindable runner" do
      expect{
        subject.send(:load_runner, "foo").should == ParallelTests::RSpec::Runner
      }.to raise_error(LoadError)
    end
  end

  describe "#final_fail_message" do
    before do
      subject.instance_variable_set(:@runner, ParallelTests::Test::Runner)
    end

    it 'returns a plain fail message if colors are nor supported' do
      subject.should_receive(:use_colors?).and_return(false)
      subject.send(:final_fail_message).should ==  "Tests Failed"
    end

    it 'returns a colorized fail message if colors are supported' do
      subject.should_receive(:use_colors?).and_return(true)
      subject.send(:final_fail_message).should == "\e[31mTests Failed\e[0m"
    end
  end
end



module ParallelTests
  module MyTestRunner
    class Runner
    end
  end
end

