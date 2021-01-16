require "spec_helper"
require "parallel_tests/gherkin/runner_behaviour"
require "parallel_tests/cucumber/runner"

describe ParallelTests::Cucumber::Runner do
  test_tests_in_groups(ParallelTests::Cucumber::Runner, ".feature")

  it_should_behave_like 'gherkin runners' do
    let(:runner_name) { 'cucumber' }
    let(:runner_class) { ParallelTests::Cucumber::Runner }

    describe :summarize_results do
      def call(*args)
        runner_class.summarize_results(*args)
      end

      it "collates failing scenarios" do
        results = [
          "Failing Scenarios:", "cucumber features/failure:1", "cucumber features/failure:2",
          "Failing Scenarios:", "cucumber features/failure:3", "cucumber features/failure:4",
          "Failing Scenarios:", "cucumber features/failure:5", "cucumber features/failure:6"
        ]
        expect(call(results)).to eq("Failing Scenarios:\ncucumber features/failure:1\ncucumber features/failure:2\ncucumber features/failure:3\ncucumber features/failure:4\ncucumber features/failure:5\ncucumber features/failure:6\n\n")
      end

      it "collates flaky scenarios separately" do
        results = [
          "Failing Scenarios:", "cucumber features/failure:1", "cucumber features/failure:2",
          "Flaky Scenarios:", "cucumber features/failure:3", "cucumber features/failure:4",
          "Failing Scenarios:", "cucumber features/failure:5", "cucumber features/failure:6",
          "Flaky Scenarios:", "cucumber features/failure:7", "cucumber features/failure:8"
        ]
        expect(call(results)).to eq("Failing Scenarios:\ncucumber features/failure:1\ncucumber features/failure:2\ncucumber features/failure:5\ncucumber features/failure:6\n\nFlaky Scenarios:\ncucumber features/failure:3\ncucumber features/failure:4\ncucumber features/failure:7\ncucumber features/failure:8\n\n")
      end
    end
  end

  describe ".command_with_seed" do
    def call(part)
      ParallelTests::Cucumber::Runner.command_with_seed("cucumber#{part}", 555)
    end

    it "adds the randomized seed" do
      expect(call("")).to eq("cucumber --order random:555")
    end

    it "does not duplicate existing random command" do
      expect(call(" --order random good1.feature")).to eq("cucumber good1.feature --order random:555")
    end

    it "does not duplicate existing random command with seed" do
      expect(call(" --order random:123 good1.feature")).to eq("cucumber good1.feature --order random:555")
    end
  end
end
