require "parallel_tests/gherkin_bdd/runner"

module ParallelTests
  module Cucumber
    class Runner < ParallelTests::GherkinBDD::Runner
      class << self
        def name
          'cucumber'
        end
      end
    end
  end
end
