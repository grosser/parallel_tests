# frozen_string_literal: true
require 'spec_helper'
require 'parallel_tests/gherkin/io'
require 'parallel_tests/cucumber/failures_logger'
require 'cucumber/configuration'

describe ParallelTests::Cucumber::FailuresLogger do
  let(:parallel_cucumber_failures) { StringIO.new }
  let(:config) { Cucumber::Configuration.new(out_stream: parallel_cucumber_failures) }

  let(:logger1) { ParallelTests::Cucumber::FailuresLogger.new(config) }
  let(:logger2) { ParallelTests::Cucumber::FailuresLogger.new(config) }
  let(:logger3) { ParallelTests::Cucumber::FailuresLogger.new(config) }

  it "should produce a list of failing scenarios" do
    feature1 = double('feature', file: "feature/one.feature")
    feature2 = double('feature', file: "feature/two.feature")

    logger1.instance_variable_set("@failures", { feature1.file => [1, 3] })
    logger2.instance_variable_set("@failures", { feature2.file => [2, 4] })
    logger3.instance_variable_set("@failures", {})

    config.event_bus.broadcast(Cucumber::Events::TestRunFinished.new)
    parallel_cucumber_failures.rewind

    expect(parallel_cucumber_failures.read).to eq 'feature/one.feature:1 feature/one.feature:3 feature/two.feature:2 feature/two.feature:4 '
  end
end
