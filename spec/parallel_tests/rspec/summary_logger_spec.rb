require 'spec_helper'

describe ParallelTests::RSpec::SummaryLogger do
  let(:output){ OutputLogger.new([]) }
  let(:logger){ ParallelTests::RSpec::SummaryLogger.new(output) }

  it "prints failing examples" do
    logger.dump_failures(double(:failure_notifications => [1], :fully_formatted_failed_examples => "HEYHO"))
    expect(output.output).to eq([
      "HEYHO\n"
    ])
  end
end
