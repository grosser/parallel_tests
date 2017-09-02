require 'cucumber/core/gherkin/tag_expression'
require 'cucumber/runtime'
require 'cucumber'
require 'parallel_tests/cucumber/scenario_line_logger'
require 'parallel_tests/gherkin/listener'
require 'gherkin/errors'

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

          # Create the tag expression instance from gherkin, this is needed to know if the scenario matches with the tags invoked by the request
          tag_expression = ::Cucumber::Core::Gherkin::TagExpression.new(tags)

          # Create the ScenarioLineLogger which will filter the scenario we want
          scenario_line_logger = ParallelTests::Cucumber::Formatters::ScenarioLineLogger.new(tag_expression)

          # here we loop on the files map, each file will contain one or more scenario
          features ||= files.map do |path|
            # Gather up any line numbers attached to the file path
            path, *test_lines = path.split(/:(?=\d+)/)
            test_lines.map!(&:to_i)

            # We encode the file and get the content of it
            source = ::Cucumber::Runtime::NormalisedEncodingFile.read(path)
            # We create a Gherkin document, this will be used to decode the details of each scenario
            document = ::Cucumber::Core::Gherkin::Document.new(path, source)

            # We create a parser for the gherkin document
            parser  = ::Gherkin::Parser.new()
            scanner = ::Gherkin::TokenScanner.new(document.body)

            begin
              # We make an attempt to parse the gherkin document, this could be failed if the document is not well formatted
              result = parser.parse(scanner)
              feature_tags = result[:feature][:tags].map { |tag| ::Cucumber::Core::Ast::Tag.new(tag[:location], tag[:name]) }

              # We loop on each children of the feature
              result[:feature][:children].each do |feature_element|
                # If the type of the child is not a scenario or scenario outline, we continue, we are only interested by the name of the scenario here
                next unless /Scenario/.match(feature_element[:type])

                # It's a scenario, we add it to the scenario_line_logger
                scenario_line_logger.visit_feature_element(document.uri, feature_element, feature_tags, line_numbers: test_lines)
              end

            rescue StandardError => e
              # Exception if the document is no well formated or error in the tags
              raise ::Cucumber::Core::Gherkin::ParseError.new("#{document.uri}: #{e.message}")
            end
          end

          scenario_line_logger.scenarios
        end
      end
    end
  end
end
