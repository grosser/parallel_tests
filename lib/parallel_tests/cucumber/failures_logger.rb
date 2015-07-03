require 'cucumber/formatter/rerun'
require 'parallel_tests/gherkin/io'

module ParallelTests
  module Cucumber
    class FailuresLogger < ::Cucumber::Formatter::Rerun
      include ParallelTests::Gherkin::Io

      def initialize(runtime, path_or_io, options)
        @io = prepare_io(path_or_io)
        super
      end

      def done
        unless @failures.empty?
          lock_output do
            @failures.each do |file, lines|
              lines.each do |line|
                @io.puts "#{file}:#{line}"
              end
            end
          end
        end
      end

    end
  end
end
