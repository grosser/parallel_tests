require 'cucumber/tag_expressions/parser'
require 'cucumber/core/gherkin/tag_expression'

module ParallelTests
  module Cucumber
    module Formatters
      class ScenarioLineLogger
        attr_reader :scenarios

        def initialize(tag_expression = ::Cucumber::Core::Gherkin::TagExpression.new([]))
          @scenarios = []
          @tag_expression = tag_expression
        end

        def visit_feature_element(uri, feature_element, feature_tags, line_numbers: [])
          scenario_tags = feature_element[:tags].map { |tag| tag[:name] }
          scenario_tags = feature_tags + scenario_tags
          if feature_element[:examples].nil? # :Scenario
            test_line = feature_element[:location][:line]

            # We don't accept the feature_element if the current tags are not valid
            return unless @tag_expression.evaluate(scenario_tags)
            # or if it is not at the correct location
            return if line_numbers.any? && !line_numbers.include?(test_line)

            @scenarios << [uri, feature_element[:location][:line]].join(":")
          else # :ScenarioOutline
            feature_element[:examples].each do |example|
              example_tags = example[:tags].map { |tag| tag[:name] }
              example_tags = scenario_tags + example_tags
              next unless @tag_expression.evaluate(example_tags)
              rows = example[:tableBody].select { |body| body[:type] == :TableRow }
              rows.each do |row|
                test_line = row[:location][:line]
                next if line_numbers.any? && !line_numbers.include?(test_line)

                @scenarios << [uri, test_line].join(':')
              end
            end
          end
        end

        def method_missing(*args)
        end
      end
    end
  end
end
