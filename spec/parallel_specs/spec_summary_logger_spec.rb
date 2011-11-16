require 'spec_helper'

describe ParallelSpecs::SpecSummaryLogger do
  let(:output){ OutputLogger.new([]) }
  let(:logger){ ParallelSpecs::SpecSummaryLogger.new(output) }

  it "should print a summary of failing examples" do
    logger.example_failed mock(:location => '/my/spec/path/to/example.rb:123', :description => 'should do stuff', :header => 'HEAD', :exception => mock(:backtrace => []))
    logger.example_failed mock(:location => '/my/spec/path/to/example.rb:125', :description => 'should not do stuff', :header => 'HEAD', :exception => mock(:backtrace => []))
    logger.dump_failure
    output.output[0].should == '2 examples failed:'
    output.output[-2..-1].should == [
      "bundle exec rspec ./spec/path/to/example.rb:123 # should do stuff",
      "bundle exec rspec ./spec/path/to/example.rb:125 # should not do stuff"
    ]
  end

  it "does not print anything for passing examples" do
    logger.example_passed mock(:location => "/my/spec/foo.rb:123")
    logger.dump_failure
    output.output.should == []
    logger.dump_summary(1,2,3,4)
    output.output.should == ["2 run, 3 failed, 4 pending"]
  end

  it "does not print anything for pending examples" do
    logger.example_pending mock(:location => "/my/spec/foo.rb:123")
    logger.dump_failure
    output.output.should == []
    logger.dump_summary(1,2,3,4)
    output.output.should == ["2 run, 3 failed, 4 pending"]
  end
end
