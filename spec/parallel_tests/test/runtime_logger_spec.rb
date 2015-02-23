require 'spec_helper'
require 'test/unit/ui/xml/testrunner'

describe ParallelTests::Test::RuntimeLogger do
  def run_tests
    result = `#{Bundler.root}/bin/parallel_test test -n 2 2>&1`
    raise "FAILED: #{result}" unless $?.success?
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

  it "writes a correct log on minitest-4" do
    use_temporary_directory do
      # setup simple structure
      FileUtils.mkdir "test"
      2.times do |i|
        File.write("test/#{i}_test.rb", <<-RUBY)
          require 'minitest/autorun'
          require 'parallel_tests/test/runtime_logger'

          class Foo#{i} < MiniTest::Unit::TestCase
            def test_foo
              sleep 0.5
              assert true
            end
          end

          class Bar#{i} < MiniTest::Unit::TestCase
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

  it 'passes correct test to log' do
    class FakeUnitTest < Test::Unit::TestCase
      def test_fake
        assert true
      end
    end

    ParallelTests::Test::RuntimeLogger.
      should_receive(:log).
      with(FakeUnitTest, kind_of(Float))

    my_tests = Test::Unit::TestSuite.new
    my_tests << FakeUnitTest.new('test_fake')
    output = StringIO.new
    Test::Unit::UI::XML::TestRunner.run(my_tests, :output => output)
  end
end
