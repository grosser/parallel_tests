require "parallel_tests/gherkin/runner"

module ParallelTests
  module Cucumber
    class Runner < ParallelTests::Gherkin::Runner
      FAILED_SCENARIO_REGEX = /^cucumber features\/.+:\d+/

      class << self
        def name
          'cucumber'
        end

        def line_is_result?(line)
          super || line =~ FAILED_SCENARIO_REGEX
        end

        def summarize_results(results)
          output = []

          failing_scenarios = results.grep(FAILED_SCENARIO_REGEX)
          if failing_scenarios.any?
            failing_scenarios.unshift("Failing Scenarios:")
            output << failing_scenarios.join("\n")
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
