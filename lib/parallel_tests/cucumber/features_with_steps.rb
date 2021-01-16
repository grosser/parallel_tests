# frozen_string_literal: true
begin
  gem "cuke_modeler", "~> 3.0"
  require 'cuke_modeler'
rescue LoadError
  raise 'Grouping by number of cucumber steps requires the `cuke_modeler` modeler gem with requirement `~> 3.0`. Add `gem "cuke_modeler", "~> 3.0"` to your `Gemfile`, run `bundle install` and try again.'
end

module ParallelTests
  module Cucumber
    class FeaturesWithSteps
      class << self
        def all(tests, options)
          ignore_tag_pattern = options[:ignore_tag_pattern].nil? ? nil : Regexp.compile(options[:ignore_tag_pattern])
          # format of hash will be FILENAME => NUM_STEPS
          steps_per_file = tests.each_with_object({}) do |file, steps|
            feature = ::CukeModeler::FeatureFile.new(file).feature

            # skip feature if it matches tag regex
            next if feature.tags.grep(ignore_tag_pattern).any?

            # count the number of steps in the file
            # will only include a feature if the regex does not match
            all_steps = feature.scenarios.map { |a| a.steps.count if a.tags.grep(ignore_tag_pattern).empty? }.compact
            steps[file] = all_steps.sum
          end
          steps_per_file.sort_by { |_, value| -value }
        end
      end
    end
  end
end
