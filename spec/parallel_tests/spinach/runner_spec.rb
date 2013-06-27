require "spec_helper"
require "parallel_tests/gherkin/runner_behavour"
require "parallel_tests/spinach/runner"

describe ParallelTests::Spinach::Runner do
  RUNNER_CLASS =ParallelTests::Spinach::Runner
  NAME ='spinach'
  it_should_behave_like 'gherkin runners'
end
