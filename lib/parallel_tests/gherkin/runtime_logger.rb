require 'parallel_tests/gherkin/io'

module ParallelTests
  module Gherkin
    class RuntimeLogger
      include Io

      def initialize(step_mother, path_or_io, options)
        @io = prepare_io(path_or_io)
        @example_times = Hash.new(0)
      end

      def before_feature(_)
        @start_at = ParallelTests.now.to_f
      end

      def after_feature(feature)
        @example_times[feature.file] += ParallelTests.now.to_f - @start_at
      end

      def after_features(*args)
        lock_output do
          @io.puts @example_times.map { |file, time| "#{file}:#{time}" }
        end
      end
    end
  end
end
