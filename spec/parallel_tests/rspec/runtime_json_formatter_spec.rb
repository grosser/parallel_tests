# frozen_string_literal: true

require "spec_helper"
require "parallel_tests/rspec/runtime_json_formatter"

RSpec.describe ParallelTests::RSpec::RuntimeJsonFormatter do
  describe "#initialize" do
    it "parses valid JSON output" do
      json_output = '{"examples": [{"file_path": "spec/models/user_spec.rb"}]}'
      formatter = described_class.new(json_output)

      expect(formatter.instance_variable_get(:@data)).to eq(
        {
          "examples" => [{ "file_path" => "spec/models/user_spec.rb" }]
        }
      )
    end

    it "handles invalid JSON gracefully" do
      invalid_json = "not valid json"
      formatter = described_class.new(invalid_json)

      expect(formatter.instance_variable_get(:@data)).to eq({ "examples" => [] })
    end

    it "handles empty JSON gracefully" do
      formatter = described_class.new("")

      expect(formatter.instance_variable_get(:@data)).to eq({ "examples" => [] })
    end
  end

  describe "#example_files" do
    it "returns unique file paths from examples" do
      json_output = JSON.generate(
        {
          "examples" => [
            { "file_path" => "spec/models/user_spec.rb" },
            { "file_path" => "spec/models/post_spec.rb" },
            { "file_path" => "spec/models/user_spec.rb" } # dup
          ]
        }
      )

      formatter = described_class.new(json_output)

      expect(formatter.example_files).to contain_exactly(
        "spec/models/user_spec.rb",
        "spec/models/post_spec.rb"
      )
    end

    it "returns empty array when no examples" do
      json_output = JSON.generate({ "examples" => [] })
      formatter = described_class.new(json_output)

      expect(formatter.example_files).to eq([])
    end

    it "returns empty array when examples are missing file_path" do
      json_output = JSON.generate(
        {
          "examples" => [
            { "status" => "passed" },
            { "description" => "some test" }
          ]
        }
      )

      formatter = described_class.new(json_output)

      expect(formatter.example_files).to eq([])
    end

    it "filters out nil file paths" do
      json_output = JSON.generate(
        {
          "examples" => [
            { "file_path" => "spec/models/user_spec.rb" },
            { "file_path" => nil },
            { "file_path" => "spec/models/post_spec.rb" }
          ]
        }
      )

      formatter = described_class.new(json_output)

      expect(formatter.example_files).to contain_exactly(
        "spec/models/user_spec.rb",
        "spec/models/post_spec.rb"
      )
    end

    it "handles malformed JSON by returning empty array" do
      formatter = described_class.new("invalid json")

      expect(formatter.example_files).to eq([])
    end

    it "works with real RSpec JSON structure" do
      json_output = JSON.generate(
        {
          "examples" => [
            {
              "id" => "./spec/models/user_spec.rb[1:1]",
              "description" => "should be valid",
              "full_description" => "User should be valid",
              "status" => "passed",
              "file_path" => "./spec/models/user_spec.rb",
              "line_number" => 5,
              "run_time" => 0.1
            },
            {
              "id" => "./spec/controllers/users_controller_spec.rb[1:1]",
              "description" => "should get index",
              "full_description" => "UsersController GET #index should get index",
              "status" => "passed",
              "file_path" => "./spec/controllers/users_controller_spec.rb",
              "line_number" => 8,
              "run_time" => 0.2
            }
          ],
          "summary" => {
            "duration" => 0.3,
            "example_count" => 2,
            "failure_count" => 0,
            "pending_count" => 0
          }
        }
      )

      formatter = described_class.new(json_output)

      expect(formatter.example_files).to contain_exactly(
        "./spec/models/user_spec.rb",
        "./spec/controllers/users_controller_spec.rb"
      )
    end
  end
end
