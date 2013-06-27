require "spec_helper"
require "parallel_tests/gherkin/runner_behavour"
require "parallel_tests/cucumber/runner"

describe ParallelTests::Cucumber::Runner do
  RUNNER_CLASS =ParallelTests::Cucumber::Runner
  NAME ='cucumber'
  it_should_behave_like 'gherkin runners'
end
