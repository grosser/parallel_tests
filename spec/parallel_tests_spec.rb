require File.dirname(__FILE__) + '/spec_helper'

describe ParallelTests do
  test_tests_in_groups(ParallelTests, 'test', '_test.rb')

  describe :parse_rake_args do
    it "should return the count" do
      args = {:count => 2}
      ParallelTests.parse_rake_args(args).should == [2, '', ""]
    end

    it "should default to the prefix" do
      args = {:count => "models"}
      ParallelTests.parse_rake_args(args).should == [Parallel.processor_count, "models", ""]
    end

    it "should return the count and prefix" do
      args = {:count => 2, :path_prefix => "models"}
      ParallelTests.parse_rake_args(args).should == [2, "models", ""]
    end

    it "should return the count, prefix, and options" do
      args = {:count => 2, :path_prefix => "plain", :options => "-p default" }
      ParallelTests.parse_rake_args(args).should == [2, "plain", "-p default"]
    end
  end

  describe :run_tests do
    it "uses TEST_ENV_NUMBER=blank when called for process 0" do
      ParallelTests.should_receive(:open).with{|x,y|x=~/TEST_ENV_NUMBER= /}.and_return mocked_process
      ParallelTests.run_tests(['xxx'],0,'')
    end

    it "uses TEST_ENV_NUMBER=2 when called for process 1" do
      ParallelTests.should_receive(:open).with{|x,y| x=~/TEST_ENV_NUMBER=2/}.and_return mocked_process
      ParallelTests.run_tests(['xxx'],1,'')
    end

    it "uses options" do
      ParallelTests.should_receive(:open).with{|x,y| x=~ %r{ruby -Itest -v}}.and_return mocked_process
      ParallelTests.run_tests(['xxx'],1,'-v')
    end

    it "returns the output" do
      io = open('spec/spec_helper.rb')
      ParallelTests.stub!(:print)
      ParallelTests.should_receive(:open).and_return io
      ParallelTests.run_tests(['xxx'],1,'').should =~ /\$LOAD_PATH << File/
    end
  end

  describe :test_in_groups do
    it "does not sort when passed false do_sort option" do
      ParallelTests.should_not_receive(:smallest_first)
      ParallelTests.tests_in_groups [], 1, :no_sort => true
    end

    it "does sort when not passed do_sort option" do
      ParallelTests.stub!(:tests_with_runtime).and_return([])
      ParallelTests::Grouper.should_receive(:smallest_first).and_return([])
      ParallelTests.tests_in_groups [], 1
    end
  end

  describe :find_results do
    it "finds multiple results in test output" do
      output = <<EOF
Loaded suite /opt/ruby-enterprise/lib/ruby/gems/1.8/gems/rake-0.8.4/lib/rake/rake_test_loader
Started
..............
Finished in 0.145069 seconds.

10 tests, 20 assertions, 0 failures, 0 errors
Loaded suite /opt/ruby-enterprise/lib/ruby/gems/1.8/gems/rake-0.8.4/lib/rake/rake_test_loader
Started
..............
Finished in 0.145069 seconds.

14 tests, 20 assertions, 0 failures, 0 errors

EOF

      ParallelTests.find_results(output).should == ['10 tests, 20 assertions, 0 failures, 0 errors','14 tests, 20 assertions, 0 failures, 0 errors']
    end

    it "is robust against scrambeled output" do
      output = <<EOF
Loaded suite /opt/ruby-enterprise/lib/ruby/gems/1.8/gems/rake-0.8.4/lib/rake/rake_test_loader
Started
..............
Finished in 0.145069 seconds.

10 tests, 20 assertions, 0 failures, 0 errors
Loaded suite /opt/ruby-enterprise/lib/ruby/gems/1.8/gems/rake-0.8.4/lib/rake/rake_test_loader
Started
..............
Finished in 0.145069 seconds.

14 te.dsts, 20 assertions, 0 failures, 0 errors
EOF

      ParallelTests.find_results(output).should == ['10 tests, 20 assertions, 0 failures, 0 errors','14 tedsts, 20 assertions, 0 failures, 0 errors']
    end
  end

  describe :failed do
    it "fails with single failed" do
      ParallelTests.failed?(['10 tests, 20 assertions, 0 failures, 0 errors','10 tests, 20 assertions, 1 failure, 0 errors']).should == true
    end

    it "fails with single error" do
      ParallelTests.failed?(['10 tests, 20 assertions, 0 failures, 1 errors','10 tests, 20 assertions, 0 failures, 0 errors']).should == true
    end

    it "fails with failed and error" do
      ParallelTests.failed?(['10 tests, 20 assertions, 0 failures, 1 errors','10 tests, 20 assertions, 1 failures, 1 errors']).should == true
    end

    it "fails with multiple failed tests" do
      ParallelTests.failed?(['10 tests, 20 assertions, 2 failures, 0 errors','10 tests, 1 assertion, 1 failures, 0 errors']).should == true
    end

    it "does not fail with successful tests" do
      ParallelTests.failed?(['10 tests, 20 assertions, 0 failures, 0 errors','10 tests, 20 assertions, 0 failures, 0 errors']).should == false
    end

    it "does fail with 10 failures" do
      ParallelTests.failed?(['10 tests, 20 assertions, 10 failures, 0 errors','10 tests, 20 assertions, 0 failures, 0 errors']).should == true
    end

    it "is not failed with empty results" do
      ParallelTests.failed?(['0 tests, 0 assertions, 0 failures, 0 errors']).should == false
    end

    it "is failed when there are no results" do
      ParallelTests.failed?([]).should == true
    end
  end

  describe :bundler_enabled? do
    it "should return false" do
      use_temporary_directory_for do
        ParallelTests.send(:bundler_enabled?).should == false
      end
    end

    it "should return true when there is a constant called Bundler" do
      use_temporary_directory_for do
        Object.stub!(:const_defined?).with(:Bundler).and_return true
        ParallelTests.send(:bundler_enabled?).should == true
      end
    end

    it "should be true when there is a Gemfile" do
      use_temporary_directory_for do
        FileUtils.touch("Gemfile")
        ParallelTests.send(:bundler_enabled?).should == true
      end
    end

    it "should be true when there is a Gemfile in the parent directory" do
      use_temporary_directory_for do
        FileUtils.touch(File.join("..", "Gemfile"))
        ParallelTests.send(:bundler_enabled?).should == true
      end
    end
  end

  it "has a version" do
    ParallelTests::VERSION.should =~ /^\d+\.\d+\.\d+$/
  end
end
