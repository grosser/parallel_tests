require "parallel_tests/gherkin_bdd/runner"

module ParallelTests
  module Spinach
    class Runner < ParallelTests::GherkinBDD::Runner
      class << self
        def name
          'spinach'
        end
        def runtime_logging
          #Not Yet Supported
          ""
        end



      end

    end
  end
end
