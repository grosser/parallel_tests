require 'cucumber/core/gherkin/tag_expression'
require 'cucumber/runtime'
require 'cucumber'
require 'parallel_tests/cucumber/scenario_line_logger'
require 'parallel_tests/gherkin/listener'

module ParallelTests
  module Cucumber
    class Scenarios
      class << self
        def all(files, options={})
          tags = []
          tags.concat options[:ignore_tag_pattern].to_s.split(/\s*,\s*/).map {|tag| "~#{tag}" }
          tags.concat options[:test_options].to_s.scan(/(?:-t|--tags) (~?@[\w,~@]+)/).flatten
          split_into_scenarios files, tags.uniq
        end

        private

        def split_into_scenarios(files, tags=[])
          tag_expression = ::Gherkin::TagExpression.new(tags)
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
end
