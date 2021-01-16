# frozen_string_literal: true
require "spec_helper"
require "parallel_tests/gherkin/runner_behaviour"
require "parallel_tests/spinach/runner"

describe ParallelTests::Spinach::Runner do
  test_tests_in_groups(ParallelTests::Spinach::Runner, ".feature")

  it_should_behave_like 'gherkin runners' do
    let(:runner_name) { 'spinach' }
    let(:runner_class) { ParallelTests::Spinach::Runner }
  end
end
