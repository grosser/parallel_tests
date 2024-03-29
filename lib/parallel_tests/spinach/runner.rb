# frozen_string_literal: true
require "parallel_tests/gherkin/runner"

module ParallelTests
  module Spinach
    class Runner < ParallelTests::Gherkin::Runner
      class << self
        def name
          'spinach'
        end

        def default_test_folder
          'features'
        end

        def runtime_logging
          # Not Yet Supported
          []
        end
      end
    end
  end
end
