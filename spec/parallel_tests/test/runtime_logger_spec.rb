require 'spec_helper'

describe ParallelTests::Test::RuntimeLogger do
  describe :writing do
    around do |example|
      use_temporary_directory_for do
        FileUtils.mkdir_p(File.dirname(log))
        example.call
      end
    end

    let(:log) { ParallelTests::Test::Runner.runtime_log }

    it "overwrites the runtime_log file on first log invocation" do
      class FakeTest
      end
      test = FakeTest.new
      time = Time.now
      File.open(log, 'w'){ |f| f.puts("FooBar") }
      ParallelTests::Test::RuntimeLogger.send(:class_variable_set,:@@has_started, false)
      ParallelTests::Test::RuntimeLogger.log(test, time, Time.at(time.to_f+2.00))
      result = File.read(log)
      result.should_not include('FooBar')
      result.should include('test/fake_test.rb:2.00')
    end

    it "appends to the runtime_log file after first log invocation" do
      class FakeTest
      end
      test = FakeTest.new
      class OtherFakeTest
      end
      other_test = OtherFakeTest.new

      time = Time.now
      File.open(log, 'w'){ |f| f.puts("FooBar") }
      ParallelTests::Test::RuntimeLogger.send(:class_variable_set,:@@has_started, false)
      ParallelTests::Test::RuntimeLogger.log(test, time, Time.at(time.to_f+2.00))
      ParallelTests::Test::RuntimeLogger.log(other_test, time, Time.at(time.to_f+2.00))
      result = File.read(log)
      result.should_not include('FooBar')
      result.should include('test/fake_test.rb:2.00')
      result.should include('test/other_fake_test.rb:2.00')
    end
  end

  describe "formatting" do
    def with_rails_defined
      Object.const_set(:Rails, Module.new)
      yield
      Object.send(:remove_const, :Rails)
    end

    def call(*args)
      ParallelTests::Test::RuntimeLogger.send(:message, *args)
    end

    it "formats results for simple test names" do
      class FakeTest
      end
      test = FakeTest.new
      time = Time.now
      call(test, time, Time.at(time.to_f+2.00)).should == 'test/fake_test.rb:2.00'
    end

    it "formats results for complex test names" do
      class AVeryComplex
        class FakeTest
        end
      end
      test = AVeryComplex::FakeTest.new
      time = Time.now
      call(test, time, Time.at(time.to_f+2.00)).should == 'test/a_very_complex/fake_test.rb:2.00'
    end

    it "guesses subdirectory structure for rails test classes" do
      with_rails_defined do
        class ActionController
          class TestCase
          end
        end
        class FakeControllerTest < ActionController::TestCase
        end
        test = FakeControllerTest.new
        time = Time.now
        call(test, time, Time.at(time.to_f+2.00)).should == 'test/functional/fake_controller_test.rb:2.00'
      end
    end
  end

  describe '::Test::Unit::TestSuite' do
    it 'passes correct parameters to log' do
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
end
