require "parallel_tests/gherkin/runner"

module ParallelTests
  module Cucumber
    class Runner < ParallelTests::Gherkin::Runner
      class << self
        def name
          'cucumber'
        end

        def determine_executable
          case
          when File.exists?("bin/cucumber")
            "bin/cucumber"
          when ParallelTests.bundler_enabled?
            "bundle exec cucumber"
          when File.file?("script/cucumber")
            "script/cucumber"
          else
            "cucumber"
          end
        end

        def runtime_log
          'tmp/parallel_runtime_cucumber.log'
        end

        def test_file_name
          "feature"
        end

        def test_suffix
          ".feature"
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

        private

        def failing_scenario_regex
          /^cucumber features\/.+:\d+/
        end

        def tests_in_groups(tests, num_groups, options={})
          if options[:group_by] == :steps
            Grouper.by_steps(find_tests(tests, options), num_groups, options)
          else
            super
          end
        end
      end
    end
  end
end
