require 'cucumber/formatter/rerun'
require 'parallel_tests/gherkin/io'

module ParallelTests
  module Cucumber
    class FailuresLogger < ::Cucumber::Formatter::Rerun
      include ParallelTests::Gherkin::Io

      def initialize(runtime, path_or_io, options)
        @io = prepare_io(path_or_io)
      end

      def after_feature(feature)
        unless @lines.empty?
          lock_output do
            @lines.each do |line|
              @io.print "#{feature.file}:#{line} "
            end
          end
        end
      end

    end
  end
end
