require 'spec_helper'
require 'parallel_tests/gherkin/io'
require 'parallel_tests/cucumber/failures_logger'

describe ParallelTests::Cucumber::FailuresLogger do

  before do
    @output = OutputLogger.new([])
    allow(@output).to receive(:write)

    @logger1 = ParallelTests::Cucumber::FailuresLogger.new(nil, @output, nil)
    @logger2 = ParallelTests::Cucumber::FailuresLogger.new(nil, @output, nil)
    @logger3 = ParallelTests::Cucumber::FailuresLogger.new(nil, @output, nil)

    @feature1 = double('feature', :file => "feature/path/to/feature1.feature")
    @feature2 = double('feature', :file => "feature/path/to/feature2.feature")
    @feature3 = double('feature', :file => "feature/path/to/feature3.feature")

    @logger1.instance_variable_set("@lines", [1, 2, 3])
    @logger2.instance_variable_set("@lines", [2, 4, 6])
    @logger3.instance_variable_set("@lines", [3, 6, 9])
  end

  it "should produce a list of lines for failing scenarios" do
    @logger1.after_feature(@feature1)
    @logger2.after_feature(@feature2)
    @logger3.after_feature(@feature3)

    output_file_contents = @output.output.join("\n").concat("\n")

    expect(output_file_contents).to eq <<END
feature/path/to/feature1.feature:1
feature/path/to/feature1.feature:2
feature/path/to/feature1.feature:3
feature/path/to/feature2.feature:2
feature/path/to/feature2.feature:4
feature/path/to/feature2.feature:6
feature/path/to/feature3.feature:3
feature/path/to/feature3.feature:6
feature/path/to/feature3.feature:9
END
  end
end
