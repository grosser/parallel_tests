require "spec_helper"
require "parallel_tests/gherkin/runner_behaviour"
require "parallel_tests/cucumber/runner"

describe ParallelTests::Cucumber::Runner do
  test_tests_in_groups(ParallelTests::Cucumber::Runner, ".feature")

  it_should_behave_like 'gherkin runners' do
    let(:runner_name) {'cucumber'}
    let(:runner_class){ParallelTests::Cucumber::Runner}

    describe :summarize_results do
      def call(*args)
        runner_class().summarize_results(*args)
      end

      it "collates failing scenarios" do
        results = [
          "Failing Scenarios:", "cucumber features/failure:1", "cucumber features/failure:2",
          "Failing Scenarios:", "cucumber features/failure:3", "cucumber features/failure:4",
          "Failing Scenarios:", "cucumber features/failure:5", "cucumber features/failure:6"
        ]
        call(results).should == "Failing Scenarios:\ncucumber features/failure:1\ncucumber features/failure:2\ncucumber features/failure:3\ncucumber features/failure:4\ncucumber features/failure:5\ncucumber features/failure:6\n\n"
      end
    end
  end
end
