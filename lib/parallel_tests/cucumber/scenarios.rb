require 'gherkin/tag_expression'
require 'cucumber/runtime'
require 'cucumber'
require 'parallel_tests/cucumber/scenario_line_logger'

module ParallelTests
  module Cucumber
    class Scenarios
      def self.all(files)
        split_into_scenarios files
      end

      private

      def self.split_into_scenarios(files)
        tag_expression = Gherkin::TagExpression.new([])
        scenario_line_logger = ParallelTests::Cucumber::Formatters::ScenarioLineLogger.new(tag_expression)
        loader = ::Cucumber::Runtime::FeaturesLoader.new(files, [], tag_expression)

        loader.features.each do |feature|
          feature.accept(scenario_line_logger)
        end

        scenario_line_logger.scenarios
      end
    end
  end
end
