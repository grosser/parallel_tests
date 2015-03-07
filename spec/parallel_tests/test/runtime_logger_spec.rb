require 'spec_helper'

describe ParallelTests::Test::RuntimeLogger do
  def sh(command)
    result = `#{command} 2>&1`
    raise "FAILED: #{result}" unless $?.success?
  end

  def run_tests
    sh "#{Bundler.root}/bin/parallel_test test -n 2"
  end

  it "writes a correct log on test-unit" do
    use_temporary_directory do
      # setup simple structure
      FileUtils.mkdir "test"
      2.times do |i|
        File.write("test/#{i}_test.rb", <<-RUBY)
          require 'test/unit'
          require 'parallel_tests/test/runtime_logger'

          class Foo#{i} < Test::Unit::TestCase
            def test_foo
              sleep 0.5
              assert true
            end
          end

          class Bar#{i} < Test::Unit::TestCase
            def test_foo
              sleep 0.25
              assert true
            end
          end
        RUBY
      end

      run_tests

      # log looking good ?
      lines = File.read("tmp/parallel_runtime_test.log").split("\n").sort.map { |x|x .sub!(/\d$/, '') }
      lines.should == [
        "test/0_test.rb:0.7",
        "test/1_test.rb:0.7",
      ]
    end
  end

  # static directory with gems so it's fast on travis
  it "writes a correct log on minitest-4" do
    Dir.chdir(Bundler.root.join("spec/fixtures/minitest4")) do
      Bundler.with_clean_env do
        sh "bundle --local --quiet"
        run_tests
      end

      # log looking good ?
      lines = File.read("tmp/parallel_runtime_test.log").split("\n").sort.map { |x| x.sub(/\d$/, "") }
      lines.should == [
        "test/0_test.rb:0.7",
        "test/1_test.rb:0.7",
      ]
      FileUtils.rm("tmp/parallel_runtime_test.log")
    end
  end

  it "writes a correct log on minitest-5" do
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
              sleep 0.25
              assert true
            end
          end
        RUBY
      end

      run_tests

      # log looking good ?
      lines = File.read("tmp/parallel_runtime_test.log").split("\n").sort.map { |x| x.sub(/\d$/, "") }
      lines.should == [
        "test/0_test.rb:0.7",
        "test/1_test.rb:0.7",
      ]
    end
  end
end
