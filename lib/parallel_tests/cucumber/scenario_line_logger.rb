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
          tags = feature_element[:tags].map {|tag| ::Cucumber::Core::Ast::Tag.new(tag[:location], tag[:name])}

          # We don't accept the feature_element if the current tags are not valid
          return unless @tag_expression.evaluate(tags)
          @scenarios << [uri, feature_element[:location][:line]].join(":")

          # TODO handle scenario outlines
          # Previous code
          # when ::Cucumber::Ast::ScenarioOutline
          #   sections = feature_element.instance_variable_get(:@example_sections)
          #   sections.each { |section|
          #     rows = if section[1].respond_to?(:rows)
          #       section[1].rows
          #     else
          #       section[1].instance_variable_get(:@rows)
          #     end
          #     rows.each_with_index { |row, index|
          #       next if index == 0  # slices didn't work with jruby data structure
          #       line = if row.respond_to?(:line)
          #         row.line
          #       else
          #         row.instance_variable_get(:@line)
          #       end
          #       @scenarios << [feature_element.feature.file, line].join(":")
          #     }
          #   }
        end

        def method_missing(*args)
        end
      end
    end
  end
end
