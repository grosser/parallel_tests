#require 'spinach/formatter/rerun'
require 'parallel_tests/gherkin_bdd/io'

module ParallelTests
  module Spinach
    class FailuresLogger #< ::Spinach::Formatter::Rerun
      include ParallelTests::GherkinBDD::Io

      def initialize(runtime, path_or_io, options)
        @io = prepare_io(path_or_io)
      end

      def after_feature(feature)
        unless @lines.empty?
          lock_output do
            @lines.each do |line|
              @io.puts "#{feature.file}:#{line}"
            end
          end
        end
      end

    end
  end
end
