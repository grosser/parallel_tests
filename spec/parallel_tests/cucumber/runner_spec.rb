require "spec_helper"
require "parallel_tests/gherkin/runner_behaviour"
require "parallel_tests/cucumber/runner"

describe ParallelTests::Cucumber::Runner do
  test_tests_in_groups(ParallelTests::Cucumber::Runner, 'features', ".feature")

  def runner_name
    'cucumber'
  end

  def runner_class
    ParallelTests::Cucumber::Runner
  end

  it_should_behave_like 'gherkin runners'
end
