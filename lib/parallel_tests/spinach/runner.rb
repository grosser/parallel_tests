require "parallel_tests/gherkin_bdd/runner"

module ParallelTests
  module Spinach
    class Runner < ParallelTests::GherkinBDD::Runner
      NAME = 'Spinach'
      NAME_LOWER_CASE = 'spinach'
      class << self

        def runtime_logging
          #not yet supportd
          #" --format ParallelTests::#{NAME}::RuntimeLogger --out #{runtime_log}"
          ""
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
