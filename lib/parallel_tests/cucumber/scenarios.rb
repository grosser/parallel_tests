require 'cucumber/core/gherkin/tag_expression'
require 'cucumber/runtime'
require 'cucumber'
require 'parallel_tests/cucumber/scenario_line_logger'
require 'parallel_tests/gherkin/listener'

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
          tag_expression = ::Cucumber::Core::Gherkin::TagExpression.new(tags)
          scenario_line_logger = ParallelTests::Cucumber::Formatters::ScenarioLineLogger.new(tag_expression)

          features ||= files.map do |path|
            source = NormalisedEncodingFile.read(path)
            document = ::Cucumber::Core::Gherkin::Document.new(path, source)

            parser  = ::Gherkin::Parser.new()
            scanner = ::Gherkin::TokenScanner.new(document.body)
            core_builder = ::Cucumber::Core::Gherkin::AstBuilder.new(document.uri)

            begin
              result = parser.parse(scanner)

              result[:feature][:children].each do |feature_element|
                if feature_element[:type] != 'Scenario'
                  next
                end

                scenario_line_logger.visit_feature_element(document.uri, feature_element)
              end

            #receiver.feature core_builder.feature(result)
            rescue *PARSER_ERRORS => e
              raise Core::Gherkin::ParseError.new("#{document.uri}: #{e.message}")
            end
          end

          scenario_line_logger.scenarios
        end
      end
    end
  end
end
