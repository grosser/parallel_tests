require 'spec_helper'

describe ParallelSpecs::SpecFailuresLogger do
  before do
    @output     = OutputLogger.new([])
    @example1   = mock( 'example', :location => '/my/spec/path/to/example:123', :description => 'should do stuff' )
    @example2   = mock( 'example', :location => '/my/spec/path/to/example2:456', :description => 'should do other stuff' )
    @exception1 = mock( :to_s => 'exception', :backtrace => [ '/path/to/error/line:33' ] )
    @failure1   = mock( 'example', :location => '/path/to/example:123', :header => 'header', :exception => @exception1 )
    @logger = ParallelSpecs::SpecFailuresLogger.new( @output )
  end

  it "should produce a list of command lines for failing examples" do
    @logger.example_failed @example1
    @logger.example_failed @example2

    @logger.dump_failures

    @output.output.size.should == 2
    @output.output[0].should =~ /bundle exec r?spec .*? should do stuff/
    @output.output[1].should =~ /bundle exec r?spec .*? should do other stuff/
  end

  it "should invoke spec for rspec 1" do
    ParallelSpecs.stub!(:bundler_enabled?).and_return true
    ParallelSpecs.stub!(:run).with("bundle show rspec").and_return "/foo/bar/rspec-1.0.2"
    @logger.example_failed @example1

    @logger.dump_failures

    @output.output[0].should =~ /^bundle exec spec/
  end

  it "should invoke rspec for rspec 2" do
    ParallelSpecs.stub!(:bundler_enabled?).and_return true
    ParallelSpecs.stub!(:run).with("bundle show rspec").and_return "/foo/bar/rspec-2.0.2"
    @logger.example_failed @example1

    @logger.dump_failures

    @output.output[0].should =~ /^bundle exec rspec/
  end

  it "should return relative paths" do
    @logger.example_failed @example1
    @logger.example_failed @example2

    @logger.dump_failures

    @output.output[0].should =~ %r(\./spec/path/to/example)
    @output.output[1].should =~ %r(\./spec/path/to/example2)
  end

  it "should not log examples without location" do
    example = mock('example', :location => nil, :description => 'before :all')
    @logger.example_failed example
    @logger.dump_failures
    @output.output.should == []
  end
end
