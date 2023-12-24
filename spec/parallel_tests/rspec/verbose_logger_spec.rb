# frozen_string_literal: true

require 'spec_helper'

describe ParallelTests::RSpec::VerboseLogger do
  def run(command)
    result = IO.popen(command, err: [:child, :out], &:read)
    raise "FAILED: #{result}" unless $?.success?
    result
  end

  it 'outputs verbose information' do
    repo_root = Dir.pwd

    use_temporary_directory do
      # setup simple structure
      FileUtils.mkdir "spec"

      File.write "spec/foo_spec.rb", <<-RUBY
        describe "Foo" do
          it "foo" do
            sleep 0.5
            expect(true).to be(true)
          end
        end
      RUBY

      File.write "spec/bar_spec.rb", <<-RUBY
        describe "Bar" do
          it "bar" do
            sleep 0.25111
            expect(true).to be(true)
          end
        end
      RUBY

      result = run [
        "ruby",
        "#{repo_root}/bin/parallel_rspec",
        "-n", "2",
        "--",
        "--format", "ParallelTests::RSpec::VerboseLogger",
        "--"
      ]

      expect(result).to match(/^\[\d+\] \[(1|2)\] \[STARTED\] Foo foo$/)
      expect(result).to match(/^\[\d+\] \[(1|2)\] \[PASSED\] Foo foo$/)
      expect(result).to match(/^\[\d+\] \[(1|2)\] \[STARTED\] Bar bar$/)
      expect(result).to match(/^\[\d+\] \[(1|2)\] \[PASSED\] Bar bar$/)
    end
  end
end
