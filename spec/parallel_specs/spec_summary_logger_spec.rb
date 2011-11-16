require 'spec_helper'

describe ParallelSpecs::SpecSummaryLogger do
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
    @logger = ParallelSpecs::SpecSummaryLogger.new( @output )
  end

  it "should print a summary of failing examples" do
    @logger.example_failed( @example1 )

    @logger.dump_failure

    @output.output.should == ["bundle exec rspec ./spec/path/to/example -e \"should do stuff\""]
  end
end
