require 'parallel_tests/gherkin/io'

module ParallelTests
  module Gherkin
    class RuntimeLogger
      include Io

      def initialize(config)
        @io = prepare_io(config.out_stream)
        @example_times = Hash.new(0)

        config.on_event :test_case_started do |_|
          @start_at = ParallelTests.now.to_f
        end

        config.on_event :test_case_finished do |event|
          @example_times[event.test_case.feature.file] += ParallelTests.now.to_f - @start_at
        end

        config.on_event :test_run_finished do |_|
          lock_output do
            @io.puts @example_times.map { |file, time| "#{file}:#{time}" }
          end
        end
      end
    end
  end
end
