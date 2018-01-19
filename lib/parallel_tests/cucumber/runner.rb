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

          scenario_groups = results.slice_before(SCENARIOS_RESULTS_BOUNDARY_REGEX).group_by(&:first)
          scenario_groups.each do |header, group|
            scenarios = group.flatten.grep(SCENARIO_REGEX)
            if scenarios.any?
              output << ([header] + scenarios).join("\n")
            end
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
