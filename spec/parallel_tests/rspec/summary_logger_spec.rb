require 'spec_helper'

describe ParallelTests::RSpec::SummaryLogger do
  let(:output){ OutputLogger.new([]) }
  let(:logger){ ParallelTests::RSpec::SummaryLogger.new(output) }

  def decolorize(string)
    string.gsub(/\e\[\d+m/,'')
  end

  # TODO somehow generate a real example with an exception to test this
  xit "prints failing examples" do
    logger.example_failed XXX
    logger.example_failed XXX
    logger.dump_failures
    expect(output.output).to eq([
      "bundle exec rspec ./spec/path/to/example.rb:123 # should do stuff",
      "bundle exec rspec ./spec/path/to/example.rb:125 # should not do stuff"
    ])
  end

  it "does not print anything for passing examples" do
    logger.example_passed double(:location => "/my/spec/foo.rb:123")
    logger.dump_failures
    expect(output.output).to eq([])
    logger.dump_summary(1,2,3,4)
    expect(output.output.map{|o| decolorize(o) }).to eq(["\nFinished in 1 second\n", "2 examples, 3 failures, 4 pending"])
  end

  it "does not print anything for pending examples" do
    logger.example_pending double(:location => "/my/spec/foo.rb:123")
    logger.dump_failures
    expect(output.output).to eq([])
    logger.dump_summary(1,2,3,4)
    expect(output.output.map{|o| decolorize(o) }).to eq(["\nFinished in 1 second\n", "2 examples, 3 failures, 4 pending"])
  end
end
