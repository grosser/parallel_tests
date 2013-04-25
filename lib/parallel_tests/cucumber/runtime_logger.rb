require 'parallel_tests/cucumber/io'

module ParallelTests
  module Cucumber
    class RuntimeLogger
      include Io

      def initialize(step_mother, path_or_io, options=nil)
        @io = prepare_io(path_or_io)
        @example_times = Hash.new(0)
      end

      def before_feature(_)
        @start_at = Time.now.to_f
      end

      def after_feature(feature)
        @example_times[feature.file] += Time.now.to_f - @start_at
      end

      def after_features(*args)
        lock_output do
          @io.puts @example_times.map { |file, time| "#{file}:#{time}" }
        end
      end
    end
  end
end
