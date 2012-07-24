require 'spec_helper'

describe ParallelTests::Test::Runner do
  test_tests_in_groups(ParallelTests::Test::Runner, 'test', '_test.rb')

  describe :run_tests do
    def call(*args)
      ParallelTests::Test::Runner.run_tests(*args)
    end

    it "uses TEST_ENV_NUMBER=blank when called for process 0" do
      ParallelTests::Test::Runner.should_receive(:open).with{|x,y|x=~/TEST_ENV_NUMBER= /}.and_return mocked_process
      call(['xxx'],0,{})
    end

    it "uses TEST_ENV_NUMBER=2 when called for process 1" do
      ParallelTests::Test::Runner.should_receive(:open).with{|x,y| x=~/TEST_ENV_NUMBER=2/}.and_return mocked_process
      call(['xxx'],1,{})
    end

    it "uses options" do
      ParallelTests::Test::Runner.should_receive(:open).with{|x,y| x=~ %r{ruby -Itest .* -- -v}}.and_return mocked_process
      call(['xxx'],1,:test_options => '-v')
    end

    it "returns the output" do
      io = open('spec/spec_helper.rb')
      $stdout.stub!(:print)
      ParallelTests::Test::Runner.should_receive(:open).and_return io
      call(['xxx'],1,{})[:stdout].should =~ /\$LOAD_PATH << File/
    end
  end

  describe :test_in_groups do
    def call(*args)
      ParallelTests::Test::Runner.tests_in_groups(*args)
    end

    it "does not sort when passed false do_sort option" do
      ParallelTests::Test::Runner.should_not_receive(:smallest_first)
      call([], 1, :group_by => :found)
    end

    it "does sort when not passed do_sort option" do
      ParallelTests::Test::Runner.stub!(:tests_with_runtime).and_return([])
      ParallelTests::Grouper.should_receive(:largest_first).and_return([])
      call([], 1)
    end

    it "groups by single_process pattern and then via size" do
      ParallelTests::Test::Runner.should_receive(:with_runtime_info).
        and_return([
          ['aaa', 5],
          ['aaa2', 5],
          ['bbb', 2],
          ['ccc', 1],
          ['ddd', 1]
        ])
      result = call([], 3, :single_process => [/^a.a/])
      result.should == [["aaa", "aaa2"], ["bbb"], ["ccc", "ddd"]]
    end

    it "groups by size and adds isolated separately" do
      ParallelTests::Grouper.should_receive(:isolated).with([], [/^aaa/]).
        and_return([[['aaa']], %w[bbb ccc ddd eee]])
      ParallelTests::Test::Runner.should_receive(:with_runtime_info).
        and_return([
          ['bbb', 3],
          ['ccc', 1],
          ['ddd', 2],
          ['eee', 1]
        ])

      result = call([], 3, :isolate => true, :single_process => [/^aaa/])
      result.should == [["bbb"], ["ddd"], ["ccc", "eee"], ["aaa"]]
    end
  end

  describe :find_results do
    def call(*args)
      ParallelTests::Test::Runner.find_results(*args)
    end

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

      call(output).should == ['10 tests, 20 assertions, 0 failures, 0 errors','14 tests, 20 assertions, 0 failures, 0 errors']
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

      call(output).should == ['10 tests, 20 assertions, 0 failures, 0 errors','14 tedsts, 20 assertions, 0 failures, 0 errors']
    end

    it "ignores color-codes" do
      output = <<EOF
10 tests, 20 assertions, 0 \e[31mfailures, 0 errors
EOF
      call(output).should == ['10 tests, 20 assertions, 0 failures, 0 errors']
    end
  end

  describe :find_tests do
    def call(*args)
      ParallelTests::Test::Runner.send(:find_tests, *args)
    end

    def with_files(files)
      begin
        root = "/tmp/test-find_tests-#{rand(999)}"
        `mkdir #{root}`
        files.each do |file|
          parent = "#{root}/#{File.dirname(file)}"
          `mkdir -p #{parent}` unless File.exist?(parent)
          `touch #{root}/#{file}`
        end
        yield root
      ensure
        `rm -rf #{root}`
      end
    end

    def inside_dir(dir)
      old = Dir.pwd
      Dir.chdir dir
      yield
    ensure
      Dir.chdir old
    end

    it "finds test in folders with appended /" do
      with_files(['b/a_test.rb']) do |root|
        call(["#{root}/"]).sort.should == [
          "#{root}/b/a_test.rb",
        ]
      end
    end

    it "finds test files nested in symlinked folders" do
      with_files(['a/a_test.rb','b/b_test.rb']) do |root|
        `ln -s #{root}/a #{root}/b/link`
        call(["#{root}/b"]).sort.should == [
          "#{root}/b/b_test.rb",
          "#{root}/b/link/a_test.rb",
        ]
      end
    end

    it "finds test files but ignores those in symlinked folders" do
      with_files(['a/a_test.rb','b/b_test.rb']) do |root|
        `ln -s #{root}/a #{root}/b/link`
        call(["#{root}/b"], :symlinks => false).sort.should == [
          "#{root}/b/b_test.rb",
        ]
      end
    end

    it "finds test files nested in different folders" do
      with_files(['a/a_test.rb','b/b_test.rb', 'c/c_test.rb']) do |root|
        call(["#{root}/a", "#{root}/b"]).sort.should == [
          "#{root}/a/a_test.rb",
          "#{root}/b/b_test.rb",
        ]
      end
    end

    it "only finds tests in folders" do
      with_files(['a/a_test.rb', 'a/test.rb', 'a/test_helper.rb']) do |root|
        call(["#{root}/a"]).sort.should == [
          "#{root}/a/a_test.rb"
        ]
      end
    end

    it "finds tests in nested folders" do
      with_files(['a/b/c/d/a_test.rb']) do |root|
        call(["#{root}/a"]).sort.should == [
          "#{root}/a/b/c/d/a_test.rb"
        ]
      end
    end

    it "does not expand paths" do
      with_files(['a/x_test.rb']) do |root|
        inside_dir root do
          call(['a']).sort.should == [
            "a/x_test.rb"
          ]
        end
      end
    end

    it "finds test files in folders by pattern" do
      with_files(['a/x_test.rb','a/y_test.rb','a/z_test.rb']) do |root|
        inside_dir root do
          call(["a"], :pattern => /^a\/(y|z)_test/).sort.should == [
            "a/y_test.rb",
            "a/z_test.rb",
          ]
        end
      end
    end

    it "finds nothing if I pass nothing" do
      call(nil).should == []
    end

    it "finds nothing if I pass nothing (empty array)" do
      call([]).should == []
    end

    it "keeps invalid files" do
      call(['baz']).should == ['baz']
    end

    it "discards duplicates" do
      call(['baz','baz']).should == ['baz']
    end
  end

  describe :summarize_results do
    def call(*args)
      ParallelTests::Test::Runner.summarize_results(*args)
    end

    it "adds results" do
      call(['1 foo 3 bar','2 foo 5 bar']).should == '8 bars, 3 foos'
    end

    it "adds results with braces" do
      call(['1 foo(s) 3 bar(s)','2 foo 5 bar']).should == '8 bars, 3 foos'
    end

    it "adds same results with plurals" do
      call(['1 foo 3 bar','2 foos 5 bar']).should == '8 bars, 3 foos'
    end

    it "adds non-similar results" do
      call(['1 xxx 2 yyy','1 xxx 2 zzz']).should == '2 xxxs, 2 yyys, 2 zzzs'
    end

    it "does not pluralize 1" do
      call(['1 xxx 2 yyy']).should == '1 xxx, 2 yyys'
    end
  end
end
