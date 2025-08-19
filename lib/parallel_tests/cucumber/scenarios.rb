# frozen_string_literal: true
require 'cucumber/tag_expressions/parser'
require 'cucumber/runtime'
require 'cucumber'
require 'parallel_tests/cucumber/scenario_line_logger'
require 'parallel_tests/gherkin/listener'

begin
  gem "cuke_modeler", "~> 3.0"
  require 'cuke_modeler'
rescue LoadError
  raise 'Grouping by individual cucumber scenarios requires the `cuke_modeler` modeler gem with requirement `~> 3.0`.  Add `gem "cuke_modeler", "~> 3.0"` to your `Gemfile`, run `bundle install` and try again.'
end

module ParallelTests
  module Cucumber
    class Scenarios
      class << self
        def all(files, options = {})
          # Parse tag expression from given test options and ignore tag pattern. Refer here to understand how new tag expression syntax works - https://github.com/cucumber/cucumber/tree/master/tag-expressions
          tags = []
          words = options[:test_options] || []
          words.each_with_index { |w, i| tags << words[i + 1] if ["-t", "--tags"].include?(w) }
          if ignore = options[:ignore_tag_pattern]
            tags << "not (#{ignore})"
          end
          tags_exp = tags.compact.join(" and ")

          split_into_scenarios files, tags_exp
        end

        private

        def split_into_scenarios(files, tags = '')
          # Create the tag expression instance from cucumber tag expressions parser, this is needed to know if the scenario matches with the tags invoked by the request
          # Create the ScenarioLineLogger which will filter the scenario we want
          args = []
          args << ::Cucumber::TagExpressions::Parser.new.parse(tags) unless tags.empty?
          scenario_line_logger = ParallelTests::Cucumber::Formatters::ScenarioLineLogger.new(*args)

          # here we loop on the files map, each file will contain one or more scenario
          files.each do |path|
            # Gather up any line numbers attached to the file path
            path, *test_lines = path.split(/:(?=\d+)/)
            test_lines.map!(&:to_i)

            # We create a Gherkin document, this will be used to decode the details of each scenario
            document = ::CukeModeler::FeatureFile.new(path)
            feature = document.feature

            # Check if feature is not nil before proceeding
            if feature.nil?
              warn "No feature found in #{path}. Skipping file."
              next
            end
            
            # We make an attempt to parse the gherkin document, this could be failed if the document is not well formatted
            feature_tags = feature.tags.map(&:name)

            # We loop on each children of the feature
            test_models = feature.tests
            test_models += feature.rules.flat_map(&:tests) if feature.respond_to?(:rules) # cuke_modeler >= 3.2 supports rules
            test_models.each do |test|
              # It's a scenario, we add it to the scenario_line_logger
              scenario_line_logger.visit_feature_element(document.path, test, feature_tags, line_numbers: test_lines)
            end
          end

          scenario_line_logger.scenarios
        end
      end
    end
  end
end
