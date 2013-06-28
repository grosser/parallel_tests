require "parallel_tests/gherkin/runner"

module ParallelTests
  module Cucumber
    class Runner < ParallelTests::Gherkin::Runner
      class << self
        def name
          'cucumber'
        end
      end
    end
  end
end
