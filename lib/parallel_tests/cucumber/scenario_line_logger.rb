require 'gherkin/tag_expression'

module ParallelTests
  module Cucumber
    module Formatters
      class ScenarioLineLogger
        attr_reader :scenarios

        def initialize(tag_expression = ::Gherkin::TagExpression.new([]))
          @scenarios = []
          @tag_expression = tag_expression
        end

        def visit_feature_element(feature_element)
          return unless @tag_expression.evaluate(feature_element.source_tags)

          case feature_element
          when ::Cucumber::Ast::Scenario
            line = if feature_element.respond_to?(:line)
              feature_element.line
            else
              feature_element.instance_variable_get(:@line)
            end
            @scenarios << [feature_element.feature.file, line].join(":")
          when ::Cucumber::Ast::ScenarioOutline
            sections = feature_element.instance_variable_get(:@example_sections)
            sections.each { |section|
              # get rows from example minus headers
              rows = section[1].instance_variable_get(:@rows)[1..-1]
              rows.each { |row|
                line = row.instance_variable_get(:@line)
                @scenarios << [feature_element.feature.file, line].join(":")
              }
            }
          end
        end

        def method_missing(*args)
        end
      end
    end
  end
end
