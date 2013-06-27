require "parallel_tests/gherkin_bdd/runner"

module ParallelTests
  module Cucumber
    class Runner < ParallelTests::GherkinBDD::Runner
      NAME = 'Cucumber'
      NAME_LOWER_CASE = 'cucumber'
      class << self
        def runtime_logging
          " --format ParallelTests::GherkinBDD::RuntimeLogger --out #{runtime_log}"
        end

        def runtime_log
          "tmp/parallel_runtime_#{NAME_LOWER_CASE}.log"
        end


        def determine_executable
          case
            when File.exists?("bin/#{NAME_LOWER_CASE}")
              "bin/#{NAME_LOWER_CASE}"
            when ParallelTests.bundler_enabled?
              "bundle exec #{NAME_LOWER_CASE}"
            when File.file?("script/#{NAME_LOWER_CASE}")
              "script/#{NAME_LOWER_CASE}"
            else
              "#{NAME_LOWER_CASE}"
          end
        end

      end
    end
  end
end
