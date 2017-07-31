require "parallel_tests/gherkin/runner"
require 'cucumber'

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


        def files_from_profile(name)
          profile = ::Cucumber::Cli::ProfileLoader.new.args_from(name)
          profile.delete_if{|x| !x.match(self.test_suffix)}
        end

        def command_with_seed(cmd, seed)
          clean = cmd.sub(/\s--order\s+random(:\d+)?\b/, '')
          "#{clean} --order random:#{seed}"
        end
      end
    end
  end
end
