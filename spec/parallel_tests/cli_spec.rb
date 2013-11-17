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
      expect(call(["-n3"])).to eq defaults.merge(:count => 3)
    end

    it "parses count 0 as non-parallel" do
      expect(call(["-n0"])).to eq defaults.merge(:non_parallel => true)
    end

    it "parses non-parallel as non-parallel" do
      expect(call(["--non-parallel"])).to eq defaults.merge(:non_parallel => true)
    end

    it "finds the correct type when multiple are given" do
      call(["--type", "test", "-t", "rspec"])
      expect(subject.instance_variable_get(:@runner)).to eq ParallelTests::RSpec::Runner
    end

    it "parses nice as nice" do
      expect(call(["--nice"])).to eq defaults.merge(:nice => true)
    end
  end

  describe "#load_runner" do
    it "requires and loads default runner" do
      expect(subject).to receive(:require).with("parallel_tests/test/runner")
      expect(subject.send(:load_runner, "test")).to eq ParallelTests::Test::Runner
    end

    it "requires and loads rspec runner" do
      expect(subject).to receive(:require).with("parallel_tests/rspec/runner")
      expect(subject.send(:load_runner, "rspec")).to eq ParallelTests::RSpec::Runner
    end

    it "fails to load unfindable runner" do
      expect{
        expect(subject.send(:load_runner, "foo")).to eq ParallelTests::RSpec::Runner
      }.to raise_error(LoadError)
    end
  end

  describe "#final_fail_message" do
    before do
      subject.instance_variable_set(:@runner, ParallelTests::Test::Runner)
    end

    it 'returns a plain fail message if colors are nor supported' do
      expect(subject).to receive(:use_colors?).and_return(false)
      expect(subject.send(:final_fail_message)).to eq  "Tests Failed"
    end

    it 'returns a colorized fail message if colors are supported' do
      expect(subject).to receive(:use_colors?).and_return(true)
      expect(subject.send(:final_fail_message)).to eq "\e[31mTests Failed\e[0m"
    end
  end
end
