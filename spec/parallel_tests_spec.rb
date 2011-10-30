require 'spec_helper'

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

    it "should return the count and pattern" do
      args = {:count => 2, :pattern => "models"}
      ParallelTests.parse_rake_args(args).should == [2, "models", ""]
    end

    it "should return the count, pattern, and options" do
      args = {:count => 2, :pattern => "plain", :options => "-p default" }
      ParallelTests.parse_rake_args(args).should == [2, "plain", "-p default"]
    end

    it "should use the PARALLEL_TEST_PROCESSORS env var for processor_count if set" do
      ENV['PARALLEL_TEST_PROCESSORS'] = '28'
      ParallelTests.parse_rake_args({}).should == [28, '', '']
    end

    it "should use count over PARALLEL_TEST_PROCESSORS env var" do
      ENV['PARALLEL_TEST_PROCESSORS'] = '28'
      args = {:count => 2}
      ParallelTests.parse_rake_args(args).should == [2, '', ""]
    end
  end

  describe :run_tests do
    it "uses TEST_ENV_NUMBER=blank when called for process 0" do
      ParallelTests.should_receive(:open).with{|x,y|x=~/TEST_ENV_NUMBER= /}.and_return mocked_process
      ParallelTests.run_tests(['xxx'],0,{})
    end

    it "uses TEST_ENV_NUMBER=2 when called for process 1" do
      ParallelTests.should_receive(:open).with{|x,y| x=~/TEST_ENV_NUMBER=2/}.and_return mocked_process
      ParallelTests.run_tests(['xxx'],1,{})
    end

    it "uses options" do
      ParallelTests.should_receive(:open).with{|x,y| x=~ %r{ruby -Itest .* -- -v}}.and_return mocked_process
      ParallelTests.run_tests(['xxx'],1,:test_options => '-v')
    end

    it "returns the output" do
      io = open('spec/spec_helper.rb')
      ParallelTests.stub!(:print)
      ParallelTests.should_receive(:open).and_return io
      ParallelTests.run_tests(['xxx'],1,{})[:stdout].should =~ /\$LOAD_PATH << File/
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

    it "groups by single_process pattern and then via size" do
      ParallelTests.should_receive(:with_runtime_info).and_return([['aaa',5],['aaa2',5],['bbb',2],['ccc',1],['ddd',1]])
      result = ParallelTests.tests_in_groups [], 3, :single_process => [/^a.a/]
      result.should == [["aaa", "aaa2"], ["bbb"], ["ccc", "ddd"]]
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

    it "is robust against scrambled output" do
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

  describe :bundler_enabled? do
    before do
      Object.stub!(:const_defined?).with(:Bundler).and_return false
    end

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

  describe :find_tests do
    it "returns if root is an array" do
      ParallelTests.send(:find_tests, [1]).should == [1]
    end

    it "finds all test files" do
      begin
        root = "/tmp/test-find_tests-#{rand(999)}"
        `mkdir #{root}`
        `mkdir #{root}/a`
        `mkdir #{root}/b`
        `touch #{root}/x_test.rb`
        `touch #{root}/a/x_test.rb`
        `touch #{root}/a/test.rb`
        `touch #{root}/b/y_test.rb`
        `touch #{root}/b/test.rb`
        `ln -s #{root}/b #{root}/c`
        `ln -s #{root}/b #{root}/a/`
        ParallelTests.send(:find_tests, root).sort.should == [
          "#{root}/a/b/y_test.rb",
          "#{root}/a/x_test.rb",
          "#{root}/b/y_test.rb",
          "#{root}/c/y_test.rb",
          "#{root}/x_test.rb"
        ]
      ensure
        `rm -rf #{root}`
      end
    end

    it "finds files by pattern" do
      begin
        root = "/tmp/test-find_tests-#{rand(999)}"
        `mkdir #{root}`
        `mkdir #{root}/a`
        `touch #{root}/a/x_test.rb`
        `touch #{root}/a/y_test.rb`
        `touch #{root}/a/z_test.rb`
        ParallelTests.send(:find_tests, root, :pattern => '^a/(y|z)_test').sort.should == [
          "#{root}/a/y_test.rb",
          "#{root}/a/z_test.rb",
        ]
      ensure
        `rm -rf #{root}`
      end
    end
  end

  describe :summarize_results do
    it "adds results" do
      ParallelTests.summarize_results(['1 foo 3 bar','2 foo 5 bar']).should == '8 bars, 3 foos'
    end

    it "adds results with braces" do
      ParallelTests.summarize_results(['1 foo(s) 3 bar(s)','2 foo 5 bar']).should == '8 bars, 3 foos'
    end

    it "adds same results with plurals" do
      ParallelTests.summarize_results(['1 foo 3 bar','2 foos 5 bar']).should == '8 bars, 3 foos'
    end

    it "adds non-similar results" do
      ParallelTests.summarize_results(['1 xxx 2 yyy','1 xxx 2 zzz']).should == '2 xxxs, 2 yyys, 2 zzzs'
    end

    it "does not pluralize 1" do
      ParallelTests.summarize_results(['1 xxx 2 yyy']).should == '1 xxx, 2 yyys'
    end
  end

  it "has a version" do
    ParallelTests::VERSION.should =~ /^\d+\.\d+\.\d+$/
  end
end
