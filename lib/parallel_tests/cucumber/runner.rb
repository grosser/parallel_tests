require "parallel_tests/gherkin/runner"

module ParallelTests
  module Cucumber
    class Runner < ParallelTests::Gherkin::Runner
      class << self
        def name
          'cucumber'
        end

        def line_is_result?(line)
          super or line =~ failing_scenario_regex
        end

        def summarize_results(results)
          output = []

          failing_scenarios = results.grep(failing_scenario_regex)
          if failing_scenarios.any?
            failing_scenarios.unshift("Failing Scenarios:")
            output << failing_scenarios.join("\n")
          end

          output << super

          output.join("\n\n")
        end

        def command_with_seed(cmd, seed)
          "#{cmd} --order random:#{seed}"
        end

        private

        def failing_scenario_regex
          /^cucumber features\/.+:\d+/
        end
      end
    end
  end
end
