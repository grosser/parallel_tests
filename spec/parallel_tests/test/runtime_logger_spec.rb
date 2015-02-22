require 'spec_helper'

describe ParallelTests::Test::RuntimeLogger do
  it "writes a correct log" do
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
        RUBY
      end

      # run tests
      result = `#{Bundler.root}/bin/parallel_test test -n 2`
      raise "FAILED: #{result}" unless $?.success?

      # log looking good ?
      lines = File.read("tmp/parallel_runtime_test.log").split("\n").sort.map { |x|x .sub!(/\d$/, '') }
      lines.should == [
        "test/0_test.rb:0.5",
        "test/1_test.rb:0.5",
      ]
    end
  end

  it 'passes correct test to log' do
    require 'test/unit'
    require 'test/unit/ui/xml/testrunner'

    class FakeUnitTest < Test::Unit::TestCase
      def test_fake
        assert true
      end
    end

    ParallelTests::Test::RuntimeLogger.
      should_receive(:log).
      with(kind_of(FakeUnitTest), kind_of(Time),  kind_of(Time))

    my_tests = Test::Unit::TestSuite.new
    my_tests << FakeUnitTest.new('test_fake')
    output = StringIO.new
    Test::Unit::UI::XML::TestRunner.run(my_tests, :output => output)
  end
end
