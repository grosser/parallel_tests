# frozen_string_literal: true
module ParallelTests
  module Cucumber
    module Formatters
      class ScenarioLineLogger
        attr_reader :scenarios

        def initialize(tag_expression = nil)
          @scenarios = []
          @tag_expression = tag_expression
        end

        def visit_feature_element(uri, feature_element, feature_tags, line_numbers: [])
          scenario_tags = feature_element.tags.map(&:name)
          scenario_tags = feature_tags + scenario_tags
          if feature_element.is_a?(CukeModeler::Scenario) # :Scenario
            test_line = feature_element.source_line

            # We don't accept the feature_element if the current tags are not valid
            return unless matches_tags?(scenario_tags)
            # or if it is not at the correct location
            return if line_numbers.any? && !line_numbers.include?(test_line)

            @scenarios << [uri, feature_element.source_line].join(":")
          else # :ScenarioOutline
            feature_element.examples.each do |example|
              example_tags = example.tags.map(&:name)
              example_tags = scenario_tags + example_tags
              next unless matches_tags?(example_tags)
              example.rows[1..-1].each do |row|
                test_line = row.source_line
                next if line_numbers.any? && !line_numbers.include?(test_line)

                @scenarios << [uri, test_line].join(':')
              end
            end
          end
        end

        def method_missing(*); end # # rubocop:disable Style/MissingRespondToMissing

        private

        def matches_tags?(tags)
          @tag_expression.nil? || @tag_expression.evaluate(tags)
        end
      end
    end
  end
end
