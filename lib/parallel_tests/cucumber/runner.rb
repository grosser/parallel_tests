require "parallel_tests/gherkin/runner"

module ParallelTests
  module Cucumber
    class Runner < ParallelTests::Gherkin::Runner
      SCENARIOS_RESULTS_BOUNDARY_REGEX = /^(Failing|Flaky) Scenarios:$/
      SCENARIO_REGEX = /^cucumber features\/.+:\d+/

      class << self
        def name
          'cucumber'
        end

        def line_is_result?(line)
          super || line =~ SCENARIO_REGEX || line =~ SCENARIOS_RESULTS_BOUNDARY_REGEX
        end

        def summarize_results(results)
          output = []

          scenario_groups = results.slice_before(SCENARIOS_RESULTS_BOUNDARY_REGEX)

          failing_scenario_groups, flaky_scenario_groups = scenario_groups.partition { |group| group.first == "Failing Scenarios:" }

          failing_scenarios = failing_scenario_groups.flatten.grep(SCENARIO_REGEX)
          if failing_scenarios.any?
            failing_scenarios.unshift("Failing Scenarios:")
            output << failing_scenarios.join("\n")
          end

          flaky_scenarios = flaky_scenario_groups.flatten.grep(SCENARIO_REGEX)
          if flaky_scenarios.any?
            flaky_scenarios.unshift("Flaky Scenarios:")
            output << flaky_scenarios.join("\n")
          end

          output << super

          output.join("\n\n")
        end

        def command_with_seed(cmd, seed)
          clean = cmd.sub(/\s--order\s+random(:\d+)?\b/, '')
          "#{clean} --order random:#{seed}"
        end
      end
    end
  end
end
