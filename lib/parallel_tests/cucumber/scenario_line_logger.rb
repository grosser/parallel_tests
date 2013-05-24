require 'gherkin/tag_expression'

module ParallelTests
  module Cucumber
    module Formatters
      class ScenarioLineLogger
        attr_reader :scenarios

        def initialize(tag_expression = Gherkin::TagExpression.new([]))
          @scenarios = []
          @tag_expression = tag_expression
        end

        def visit_feature_element(feature_element)
          if @tag_expression.evaluate(feature_element.source_tags)
            line = if feature_element.respond_to?(:line)
              feature_element.line
            else
              feature_element.instance_variable_get(:@line)
            end
            @scenarios << [feature_element.feature.file, line].join(":")
          end
        end

        def method_missing(*args)
        end
      end
    end
  end
end
