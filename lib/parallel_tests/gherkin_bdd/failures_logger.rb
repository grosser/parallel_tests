require 'gherkin_bdd/formatter/rerun'
require 'parallel_tests/gherkin/io'

module ParallelTests
  module GherkinBDD
    class FailuresLogger < ::Gherkin::Formatter::Rerun
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
