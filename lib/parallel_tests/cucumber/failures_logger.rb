require 'cucumber/formatter/rerun'

module ParallelTests
  module Cucumber
    class FailuresLogger < ::Cucumber::Formatter::Rerun
      include Io

      def initialize(runtime, path_or_io, options)
        @io = prepare_io(path_or_io)
      end

      def after_feature(*)
        unless @lines.empty?
          lock_output do
            @io.puts "#{@file}:#{@lines.join(':')}"
          end
        end
      end

    end
  end
end
