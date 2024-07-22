# frozen_string_literal: true
require "parallel_tests/gherkin/runner"

module ParallelTests
  module Cucumber
    class Runner < ParallelTests::Gherkin::Runner
      SCENARIOS_RESULTS_BOUNDARY_REGEX = /^(Failing|Flaky) Scenarios:$/
      SCENARIO_REGEX = %r{^cucumber features/.+:\d+}

      class << self
        def name
          'cucumber'
        end

        def default_test_folder
          'features'
        end

        def line_is_result?(line)
          super || line =~ SCENARIO_REGEX || line =~ SCENARIOS_RESULTS_BOUNDARY_REGEX
        end

        def summarize_results(results)
          output = []

          scenario_groups = results.slice_before(SCENARIOS_RESULTS_BOUNDARY_REGEX).group_by(&:first)
          scenario_groups.each do |header, group|
            scenarios = group.flatten.grep(SCENARIO_REGEX)
            output << ([header] + scenarios).join("\n") if scenarios.any?
          end

          output << super

          output.join("\n\n")
        end

        def command_with_seed(cmd, seed)
          clean = remove_command_arguments(cmd, '--order')
          [*clean, '--order', "random:#{seed}"]
        end
      end
    end
  end
end
