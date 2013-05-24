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
          if @tag_expression.eval(feature_element.source_tag_names)
            @scenarios << if feature_element.respond_to? :line
              [feature_element.feature.file, feature_element.line].join(":")
            else
              [feature_element.feature.file, feature_element.instance_variable_get(:@line)].join(":")
            end
          end
        end

        def method_missing(*args)
        end
      end
    end
  end
end
