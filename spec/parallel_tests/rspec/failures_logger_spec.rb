require 'spec_helper'

describe ParallelTests::RSpec::FailuresLogger do
  let(:output) { OutputLogger.new([]) }
  let(:logger) { ParallelTests::RSpec::FailuresLogger.new(output) }

  it "prints failures" do
    logger.dump_summary(double(failed_examples: [1], colorized_rerun_commands: "HEYHO"))
    expect(output.output).to eq(
      [
        "HEYHO\n"
      ]
    )
  end
end
