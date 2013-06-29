require "spec_helper"
require "parallel_tests/gherkin/runner_behaviour"
require "parallel_tests/cucumber/runner"

describe ParallelTests::Cucumber::Runner do
  test_tests_in_groups(ParallelTests::Cucumber::Runner, 'features', ".feature")

  it_should_behave_like 'gherkin runners' do
    let(:runner_name) {'cucumber'}
    let(:runner_class){ParallelTests::Cucumber::Runner}
  end
end
