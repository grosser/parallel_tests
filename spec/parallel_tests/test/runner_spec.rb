require "spec_helper"
require "parallel_tests/test/runner"

describe ParallelTests::Test::Runner do
  test_tests_in_groups(ParallelTests::Test::Runner, '_test.rb')
  test_tests_in_groups(ParallelTests::Test::Runner, '_spec.rb')

  describe ".run_tests" do
    def call(*args)
      ParallelTests::Test::Runner.run_tests(*args)
    end

    it "allows to override runner executable via PARALLEL_TESTS_EXECUTABLE" do
      ENV['PARALLEL_TESTS_EXECUTABLE'] = 'script/custom_rspec'
      ParallelTests::Test::Runner.should_receive(:execute_command).with{|a,b,c,d| a.include?("script/custom_rspec") }
      call(['xxx'], 1, 22, {})
    end

    it "uses options" do
      ParallelTests::Test::Runner.should_receive(:execute_command).with{|a,b,c,d| a =~ %r{ruby -Itest .* -- -v}}
      call(['xxx'], 1, 22, :test_options => '-v')
    end

    it "returns the output" do
      ParallelTests::Test::Runner.should_receive(:execute_command).and_return({:x => 1})
      call(['xxx'], 1, 22, {}).should == {:x => 1}
    end
  end

  describe ".test_in_groups" do
    def call(*args)
      ParallelTests::Test::Runner.tests_in_groups(*args)
    end

    it "raises when passed invalid group" do
      expect { call([], 1, group_by: :sdjhfdfdjs) }.to raise_error(ArgumentError)
    end

    it "uses given when passed found" do
      call(["a", "b", "c"], 2, group_by: :found).should == [["a", "c"], ["b"]]
    end

    context "when passed no group" do
      it "sort by file size" do
        File.should_receive(:stat).with("a").and_return 1
        File.should_receive(:stat).with("b").and_return 1
        File.should_receive(:stat).with("c").and_return 3
        call(["a", "b", "c"], 2)
      end

      it "sorts by runtime when runtime is available" do
        ParallelTests::Test::Runner.should_receive(:puts).with("Using recorded test runtime")
        ParallelTests::Test::Runner.should_receive(:runtimes).and_return(["a:1", "b:1", "c:3"])
        call(["a", "b", "c"], 2).should == [["c"], ["a", "b"]]
      end

      it "sorts by filesize when runtime is too little" do
        ParallelTests::Test::Runner.should_not_receive(:puts)
        ParallelTests::Test::Runner.should_receive(:runtimes).and_return(["a:1"])
        File.should_receive(:stat).with("a").and_return 1
        File.should_receive(:stat).with("b").and_return 1
        File.should_receive(:stat).with("c").and_return 3
        call(["a", "b", "c"], 2)
      end
    end

    context "when passed runtime" do
      around { |test| Dir.mktmpdir { |dir| Dir.chdir(dir, &test) } }
      before do
        ["aaa", "bbb", "ccc", "ddd"].each { |f| File.write(f, f) }
        FileUtils.mkdir("tmp")
      end

      it "fails when there is no log" do
        lambda { call(["aaa"], 3, group_by: :runtime) }.should raise_error(Errno::ENOENT)
      end

      it "fails when there is too little log" do
        File.write("tmp/parallel_runtime_test.log", "xxx:123\nyyy:123\naaa:123")
        lambda { call(["aaa", "bbb", "ccc"], 3, group_by: :runtime) }.should raise_error(RuntimeError)
      end

      it "groups when there is enough log" do
        File.write("tmp/parallel_runtime_test.log", "xxx:123\nbbb:123\naaa:123")
        call(["aaa", "bbb", "ccc"], 3, group_by: :runtime)
      end

      it "groups with average for missing" do
        File.write("tmp/parallel_runtime_test.log", "xxx:123\nbbb:10\nccc:1")
        call(["aaa", "bbb", "ccc", "ddd"], 2, group_by: :runtime).should == [["bbb", "ccc"], ["aaa", "ddd"]]
      end

      it "groups by single_process pattern and then via size" do
        ParallelTests::Test::Runner.should_receive(:runtimes).
          and_return(%w[aaa:5 aaa2:5 bbb:2 ccc:1 ddd:1])
        result = call(["aaa", "aaa2", "bbb", "ccc", "ddd"], 3, single_process: [/^a.a/], group_by: :runtime)
        result.should == [["aaa", "aaa2"], ["bbb"], ["ccc", "ddd"]]
      end

      it "groups by size and adds isolated separately" do
        pending if RUBY_PLATFORM == "java"
        ParallelTests::Test::Runner.should_receive(:runtimes).
          and_return(%w[aaa:0 bbb:3 ccc:1 ddd:2 eee:1])
        result = call(["aaa", "bbb", "ccc", "ddd", "eee"], 3, isolate: true, single_process: [/^aaa/], group_by: :runtime)
        result.should == [["aaa"], ["bbb", "eee"], ["ccc", "ddd"]]
      end
    end
  end

  describe ".find_results" do
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

  describe ".find_tests" do
    def call(*args)
      ParallelTests::Test::Runner.send(:find_tests, *args)
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
      pending if RUBY_PLATFORM == "java"
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
        Dir.chdir root do
          call(['a']).sort.should == [
            "a/x_test.rb"
          ]
        end
      end
    end

    it "finds test files in folders by pattern" do
      with_files(['a/x_test.rb','a/y_test.rb','a/z_test.rb']) do |root|
        Dir.chdir root do
          call(["a"], :pattern => /^a\/(y|z)_test/).sort.should == [
            "a/y_test.rb",
            "a/z_test.rb",
          ]
        end
      end
    end

    it "doesn't find bakup files with the same name as test files" do
      with_files(['a/x_test.rb','a/x_test.rb.bak']) do |root|
        call(["#{root}/"]).should == [
          "#{root}/a/x_test.rb",
        ]
      end
    end

    it "finds minispec files" do
      with_files(['a/x_spec.rb']) do |root|
        call(["#{root}/"]).should == [
          "#{root}/a/x_spec.rb",
        ]
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

  describe ".summarize_results" do
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

  describe ".execute_command" do
    def call(*args)
      ParallelTests::Test::Runner.execute_command(*args)
    end

    def capture_output
      $stdout, $stderr = StringIO.new, StringIO.new
      yield
      [$stdout.string, $stderr.string]
    ensure
      $stdout, $stderr = STDOUT, STDERR
    end

    def run_with_file(content)
      capture_output do
        Tempfile.open("xxx") do |f|
          f.write(content)
          f.flush
          yield f.path
        end
      end
    end

    it "sets process number to 2 for 1" do
      run_with_file("puts ENV['TEST_ENV_NUMBER']") do |path|
        result = call("ruby #{path}", 1, 4, {})
        result.should == {
          :stdout => "2\n",
          :exit_status => 0
        }
      end
    end

    it "sets process number to '' for 0" do
      run_with_file("puts ENV['TEST_ENV_NUMBER'].inspect") do |path|
        result = call("ruby #{path}", 0, 4, {})
        result.should == {
          :stdout => "\"\"\n",
          :exit_status => 0
        }
      end
    end

    it 'sets PARALLEL_TEST_GROUPS so child processes know that they are being run under parallel_tests' do
      run_with_file("puts ENV['PARALLEL_TEST_GROUPS']") do |path|
        result = call("ruby #{path}", 1, 4, {})
        result.should == {
          :stdout => "4\n",
          :exit_status => 0
        }
      end
    end

    it "skips reads from stdin" do
      pending "hangs on normal ruby, works on jruby" unless RUBY_PLATFORM == "java"
      run_with_file("$stdin.read; puts 123") do |path|
        result = call("ruby #{path}", 1, 2, {})
        result.should == {
          :stdout => "123\n",
          :exit_status => 0
        }
      end
    end

    it "waits for process to finish" do
      run_with_file("sleep 0.5; puts 123; sleep 0.5; puts 345") do |path|
        result = call("ruby #{path}", 1, 4, {})
        result.should == {
          :stdout => "123\n345\n",
          :exit_status => 0
        }
      end
    end

    it "prints output while running" do
      pending "too slow" if RUBY_PLATFORM == " java"
      run_with_file("$stdout.sync = true; puts 123; sleep 0.1; print 345; sleep 0.1; puts 567") do |path|
        received = ""
        $stdout.stub(:print).with{|x| received << x.strip }
        result = call("ruby #{path}", 1, 4, {})
        received.should == "123345567"
        result.should == {
          :stdout => "123\n345567\n",
          :exit_status => 0
        }
      end
    end

    it "works with synced stdout" do
      run_with_file("$stdout.sync = true; puts 123; sleep 0.1; puts 345") do |path|
        result = call("ruby #{path}", 1, 4, {})
        result.should == {
          :stdout => "123\n345\n",
          :exit_status => 0
        }
      end
    end

    it "does not print to stdout with :serialize_stdout" do
      run_with_file("puts 123") do |path|
        $stdout.should_not_receive(:print)
        result = call("ruby #{path}", 1, 4, :serialize_stdout => true)
        result.should == {
          :stdout => "123\n",
          :exit_status => 0
        }
      end
    end

    it "returns correct exit status" do
      run_with_file("puts 123; exit 5") do |path|
        result = call("ruby #{path}", 1, 4, {})
        result.should == {
          :stdout => "123\n",
          :exit_status => 5
        }
      end
    end

    it "prints each stream to the correct stream" do
      pending "open3"
      out, err = run_with_file("puts 123 ; $stderr.puts 345 ; exit 5") do |path|
        result = call("ruby #{path}", 1, 4, {})
        result.should == {
          :stdout => "123\n",
          :exit_status => 5
        }
      end
      err.should == "345\n"
    end

    it "uses a lower priority process when the nice option is used" do
      priority_cmd = "puts Process.getpriority(Process::PRIO_PROCESS, 0)"
      priority_without_nice = run_with_file(priority_cmd){ |cmd| call("ruby #{cmd}", 1, 4, {}) }.first.to_i
      priority_with_nice = run_with_file(priority_cmd){ |cmd| call("ruby #{cmd}", 1, 4, :nice => true) }.first.to_i
      priority_without_nice.should < priority_with_nice
    end
  end
end
