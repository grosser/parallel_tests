# frozen_string_literal: true
require 'spec_helper'

describe ParallelTests::Test::RuntimeLogger do
  def run(command)
    result = IO.popen(command, err: [:child, :out], &:read)
    raise "FAILED: #{result}" unless $?.success?
  end

  def run_tests(repo_root_dir)
    run ["ruby", "#{repo_root_dir}/bin/parallel_test", "test", "-n", "2"]
  end

  it "writes a correct log on minitest-5" do
    skip if RUBY_PLATFORM == "java" # just too slow ...
    repo_root = Dir.pwd

    use_temporary_directory do
      # setup simple structure
      FileUtils.mkdir "test"
      2.times do |i|
        File.write("test/#{i}_test.rb", <<-RUBY)
          require 'minitest/autorun'
          require 'parallel_tests/test/runtime_logger'

          class Foo#{i} < Minitest::Test
            def test_foo
              sleep 0.5
              assert true
            end
          end

          class Bar#{i} < Minitest::Test
            def test_foo
              sleep 0.25111
              assert true
            end
          end
        RUBY
      end

      run_tests(repo_root)

      # log looking good ?
      lines = File.read("tmp/parallel_runtime_test.log").split("\n").sort.map { |x| x.sub(/\d$/, "") }
      expect(lines).to eq(
        [
          "test/0_test.rb:0.7",
          "test/1_test.rb:0.7"
        ]
      )
    end
  end

  it "can write to a custom location" do
    skip if RUBY_PLATFORM == "java" # just too slow ...
    repo_root = Dir.pwd

    use_temporary_directory do
      FileUtils.mkdir "test"
      File.write("test/a_test.rb", <<-RUBY)
        require 'minitest/autorun'
        require 'parallel_tests/test/runtime_logger'
        ParallelTests::Test::RuntimeLogger.logfile = "foo.log"

        class Bar < Minitest::Test
          def test_foo
            assert true
          end
        end
      RUBY

      run_tests(repo_root)

      expect(File.exist?("foo.log")).to eq(true)
    end
  end
end
