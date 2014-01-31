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
              rows = if section[1].respond_to?(:rows)
                section[1].rows
              else
                section[1].instance_variable_get(:@rows)
              end
              rows.each_with_index { |row, index|
                next if index == 0  # slices didn't work with jruby data structure
                line = if row.respond_to?(:line)
                  row.line
                else
                  row.instance_variable_get(:@line)
                end
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
