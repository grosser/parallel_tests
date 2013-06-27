require "spec_helper"
require "parallel_tests/gherkin/runner_behaviour"
require "parallel_tests/spinach/runner"

describe ParallelTests::Spinach::Runner do
  test_tests_in_groups(ParallelTests::Spinach::Runner, 'features', ".feature")

  def runner_name
    'spinach'
  end

  def runner_class
    ParallelTests::Spinach::Runner
  end

  it_should_behave_like 'gherkin runners'
end
