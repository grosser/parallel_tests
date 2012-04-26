require 'gherkin'

module ParallelTests
  module Cucumber
    class GherkinListener
      attr_reader :collect

      def initialize
        @steps, @uris = [], []
        @collect = {}
        reset_counters!
      end

      def background(*args)
        @background = 1
      end

      def scenario(*args)
        @scenarios += 1
        @outline = @background = 0
      end

      def scenario_outline(*args)
        @outline = 1
      end

      def step(*args)
        if @background > 0
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

      def examples(*args)
        @examples += 1
      end

      def eof(*args)
        @collect[@uri] += (@background_steps * @scenarios) + (@outline_steps * @examples)
        reset_counters!
      end

      def reset_counters!
        @examples = @outline = @outline_steps = @background = @background_steps = @scenarios = 0
      end

      # ignore lots of other possible callbacks ...
      def method_missing(*args)
      end
    end
  end
end
