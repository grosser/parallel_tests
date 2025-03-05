# frozen_string_literal: true
require 'cucumber/formatter/rerun'
require 'parallel_tests/gherkin/io'
require 'cucumber/events'

module ParallelTests
  module Cucumber
    class FailuresLogger < ::Cucumber::Formatter::Rerun
      include ParallelTests::Gherkin::Io

      def initialize(config)
        super

        @io = prepare_io(config.out_stream)

        # Remove handler inherited from Cucumber::Formatter::Rerun that does not
        # properly join file failures
        handlers = config.event_bus.instance_variable_get(:@handlers)
        handlers[::Cucumber::Events::TestRunFinished.to_s].pop

        # Add our own handler
        config.on_event :test_run_finished do
          next if @failures.empty?

          lock_output do
            @failures.each do |file, lines|
              lines.each do |line|
                @io.print "#{file}:#{line} "
              end
            end
          end
        end
      end
    end
  end
end
