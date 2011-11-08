require 'spec_helper'

describe ParallelSpecs::SpecRuntimeLogger do
  before do
    # pretend we run in parallel or the logger will log nothing
    ENV['TEST_ENV_NUMBER'] = ''
  end

  after do
    ENV.delete 'TEST_ENV_NUMBER'
  end

  it "logs runtime with relative paths" do
    Tempfile.open('xxx') do |f|
      logger = ParallelSpecs::SpecRuntimeLogger.new(f)
      logger.example_started
      logger.example_passed(mock(:location => "#{Dir.pwd}/spec/foo.rb:123"))
      logger.start_dump

      f.close
      File.read(f.path).should =~ %r{^spec/foo.rb:0.\d+$}m
    end
  end
end
