require 'spec_helper'

describe ParallelSpecs::SpecSummaryLogger do
  OutputLogger = Struct.new(:output) do
    attr_reader :flock, :flush
    def puts(s)
      self.output << s
    end
  end

  let(:output){ OutputLogger.new([]) }
  let(:logger){ ParallelSpecs::SpecSummaryLogger.new(output) }

  it "should print a summary of failing examples" do
    logger.example_failed mock(:location => '/my/spec/path/to/example:123', :description => 'should do stuff')
    logger.example_failed mock(:location => '/my/spec/path/to/example:125', :description => 'should not do stuff')
    logger.dump_failure
    output.output.should == [
      "bundle exec rspec ./spec/path/to/example -e \"should do stuff\"",
      "bundle exec rspec ./spec/path/to/example -e \"should not do stuff\""
    ]
  end

  it "does not print anything for passing examples" do
    logger.example_started
    logger.example_passed mock(:location => "/my/spec/foo.rb:123")
    logger.dump_failure
    output.output.should == []
  end
end
