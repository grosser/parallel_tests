require 'cucumber/formatter/rerun'
require 'parallel_tests/gherkin/io'

module ParallelTests
  module Cucumber
    class FailuresLogger < ::Cucumber::Formatter::Rerun
      include ParallelTests::Gherkin::Io

      def initialize(runtime, path_or_io, options)
        super
        @io = prepare_io(path_or_io)
      end

      def done
        return if @failures.empty?
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
