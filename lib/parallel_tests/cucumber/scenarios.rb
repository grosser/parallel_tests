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

        # Class stolen from cucumber as it was private
        # Private class can be found here : https://github.com/cucumber/cucumber-ruby/blob/master/lib/cucumber/runtime.rb#L130
        class NormalisedEncodingFile
          COMMENT_OR_EMPTY_LINE_PATTERN = /^\s*#|^\s*$/ #:nodoc:
          ENCODING_PATTERN = /^\s*#\s*encoding\s*:\s*([^\s]+)/ #:nodoc:

          def self.read(path)
            new(path).read
          end

          def initialize(path)
            begin
              @file = File.new(path)
              set_encoding
            rescue Errno::EACCES => e
              raise FileNotFoundException.new(e, File.expand_path(path))
            rescue Errno::ENOENT => e
              raise FeatureFolderNotFoundException.new(e, path)
            end
          end

          def read
            @file.read.encode("UTF-8")
          end

          private

          def set_encoding
            @file.each do |line|
              if ENCODING_PATTERN =~ line
                @file.set_encoding $1
                break
              end
              break unless COMMENT_OR_EMPTY_LINE_PATTERN =~ line
            end
            @file.rewind
          end
        end

        def split_into_scenarios(files, tags=[])

          # Create the tag expression instance from gherkin, this is needed to know if the scenario matches with the tags invoked by the request
          tag_expression = ::Cucumber::Core::Gherkin::TagExpression.new(tags)

          # Create the ScenarioLineLogger which will filter the scenario we want
          scenario_line_logger = ParallelTests::Cucumber::Formatters::ScenarioLineLogger.new(tag_expression)

          # here we loop on the files map, each file will containe one or more scenario
          features ||= files.map do |path|

            # We encode the file and get the content of it
            source = NormalisedEncodingFile.read(path)
            # We create a Gherkin document, this will be used to decode the details of each scenario
            document = ::Cucumber::Core::Gherkin::Document.new(path, source)

            # We create a parser for the gherkin document
            parser  = ::Gherkin::Parser.new()
            scanner = ::Gherkin::TokenScanner.new(document.body)

            begin
              # We make an attempt to parse the gherkin document, this could be failed if the document is not well formated
              result = parser.parse(scanner)

              # We loop on each children of the feature
              result[:feature][:children].each do |feature_element|
                # If the type of the child is not a scenario, we continue, we are only interested by the name of the scenario here
                if feature_element[:type].to_s != 'Scenario'
                  next
                end

                # It's a scenario, we add it to the scenario_line_logger
                scenario_line_logger.visit_feature_element(document.uri, feature_element)
              end

            rescue Exception => e
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
