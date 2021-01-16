# frozen_string_literal: true
module ParallelTests
  module Gherkin
    class Listener
      attr_reader :collect

      attr_writer :ignore_tag_pattern

      def initialize
        @steps = []
        @uris = []
        @collect = {}
        @feature, @ignore_tag_pattern = nil
        reset_counters!
      end

      def feature(feature)
        @feature = feature
      end

      def background(*)
        @background = 1
      end

      def scenario(scenario)
        @outline = @background = 0
        return if should_ignore(scenario)
        @scenarios += 1
      end

      def scenario_outline(outline)
        return if should_ignore(outline)
        @outline = 1
      end

      def step(*)
        return if @ignoring
        if @background == 1
          @background_steps += 1
        elsif @outline > 0
          @outline_steps += 1
        else
          @collect[@uri] += 1
        end
      end

      def uri(path)
        @uri = path
        @collect[@uri] = 0
      end

      #
      # @param  [Gherkin::Formatter::Model::Examples]  examples
      #
      def examples(examples)
        @collect[@uri] += (@outline_steps * examples.rows.size) unless examples.rows.empty?
      end

      def eof(*)
        @collect[@uri] += (@background_steps * @scenarios)
        reset_counters!
      end

      def reset_counters!
        @outline = @outline_steps = @background = @background_steps = @scenarios = 0
        @ignoring = nil
      end

      # ignore lots of other possible callbacks ...
      def method_missing(*); end # rubocop:disable Style/MissingRespondToMissing

      private

      # Return a combination of tags declared on this scenario/outline and the feature it belongs to
      def all_tags(scenario)
        (scenario.tags || []) + ((@feature && @feature.tags) || [])
      end

      # Set @ignoring if we should ignore this scenario/outline based on its tags
      def should_ignore(scenario)
        @ignoring = @ignore_tag_pattern && all_tags(scenario).find { |tag| @ignore_tag_pattern === tag.name }
      end
    end
  end
end
