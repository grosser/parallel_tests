require 'spec_helper'

describe ParallelSpecs::SpecFailuresLogger do
  OutputLogger = Struct.new(:output) do
    attr_reader :flock, :flush
    def puts(s)
      self.output << s
    end
  end

  before :each do
    @output     = OutputLogger.new([])
    @example1   = mock( 'example', :location => '/my/spec/path/to/example:123', :description => 'should do stuff' )
    @example2   = mock( 'example', :location => '/my/spec/path/to/example2:456', :description => 'should do other stuff' )
    @exception1 = mock( :to_s => 'exception', :backtrace => [ '/path/to/error/line:33' ] )
    @failure1   = mock( 'example', :location => '/path/to/example:123', :header => 'header', :exception => @exception1 )
  end

  before :each do
    @logger = ParallelSpecs::SpecFailuresLogger.new( @output )
  end

  it "should produce a list of command lines for failing examples" do
    @logger.example_failed( @example1, nil, nil )
    @logger.example_failed( @example2, nil, nil )

    @logger.dump_failure

    @output.output.size.should == 2
    @output.output[0].should =~ /r?spec .*? -e "should do stuff"/
    @output.output[1].should =~ /r?spec .*? -e "should do other stuff"/
  end

  it "should invoke spec for rspec 1" do
    ParallelSpecs.stub!(:bundler_enabled?).and_return true
    ParallelSpecs.stub!(:run).with("bundle show rspec").and_return "/foo/bar/rspec-1.0.2"
    @logger.example_failed( @example1, nil, nil )

    @logger.dump_failure

    @output.output[0].should =~ /^bundle exec spec/
  end

  it "should invoke rspec for rspec 2" do
    ParallelSpecs.stub!(:bundler_enabled?).and_return true
    ParallelSpecs.stub!(:run).with("bundle show rspec").and_return "/foo/bar/rspec-2.0.2"
    @logger.example_failed( @example1, nil, nil )

    @logger.dump_failure

    @output.output[0].should =~ /^bundle exec rspec/
  end

  it "should return relative paths" do
    @logger.example_failed( @example1, nil, nil )
    @logger.example_failed( @example2, nil, nil )

    @logger.dump_failure

    @output.output[0].should =~ %r(\./spec/path/to/example)
    @output.output[1].should =~ %r(\./spec/path/to/example2)
  end

end
