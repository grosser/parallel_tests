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

        def visit_feature_element(uri, feature_element)
          return unless @tag_expression.evaluate(feature_element[:tags])
          @scenarios << [uri, feature_element[:location][:line]].join(":")

          #TODO handle scenario outlines
        end

        def method_missing(*args)
        end
      end
    end
  end
end
