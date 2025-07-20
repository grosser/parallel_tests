# frozen_string_literal: true

require "json"

module ParallelTests
  module RSpec
    class RuntimeJsonFormatter
      def initialize(json_output)
        @data = JSON.parse(json_output)
      rescue JSON::ParserError
        @data = { "examples" => [] }
      end

      def example_files
        @data["examples"].map { |e| e["file_path"] }.uniq
      end
    end
  end
end
