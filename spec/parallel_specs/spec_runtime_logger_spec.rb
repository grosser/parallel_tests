require 'spec_helper'

describe ParallelSpecs::SpecRuntimeLogger do
  before do
    # pretend we run in parallel or the logger will log nothing
    ENV['TEST_ENV_NUMBER'] = ''
  end

  after do
    ENV.delete 'TEST_ENV_NUMBER'
  end

  def log_for_a_file
    Tempfile.open('xxx') do |temp|
      temp.close
      f = File.open(temp.path,'w')
      logger = if block_given?
        yield(f)
      else
        ParallelSpecs::SpecRuntimeLogger.new(f)
      end
      logger.example_started
      logger.example_passed(mock(:location => "#{Dir.pwd}/spec/foo.rb:123"))
      logger.start_dump

      #f.close
      return File.read(f.path)
    end
  end

  it "logs runtime with relative paths" do
    log_for_a_file.should =~ %r{^spec/foo.rb:0.\d+$}m
  end

  it "does not log if we do not run in parallel" do
    ENV.delete 'TEST_ENV_NUMBER'
    log_for_a_file.should == ''
  end

  it "appends to a given file" do
    result = log_for_a_file do |f|
      f.write 'FooBar'
      ParallelSpecs::SpecRuntimeLogger.new(f)
    end
    result.should include('FooBar')
    result.should include('foo.rb')
  end

  it "overwrites a given path" do
    result = log_for_a_file do |f|
      f.write 'FooBar'
      ParallelSpecs::SpecRuntimeLogger.new(f.path)
    end
    result.should_not include('FooBar')
    result.should include('foo.rb')
  end
end
