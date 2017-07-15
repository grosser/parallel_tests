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
      expect(ParallelTests::Test::Runner).to receive(:execute_command) do |a,b,c,d|
        expect(a).to include("script/custom_rspec")
      end
      call(['xxx'], 1, 22, {})
    end

    it "uses options" do
      expect(ParallelTests::Test::Runner).to receive(:execute_command) do |a,b,c,d|
        expect(a).to match(%r{ruby -Itest .* -- -v})
      end
      call(['xxx'], 1, 22, :test_options => '-v')
    end

    it "returns the output" do
      expect(ParallelTests::Test::Runner).to receive(:execute_command).and_return({:x => 1})
      expect(call(['xxx'], 1, 22, {})).to eq({:x => 1})
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
      expect(call(["a", "b", "c"], 2, group_by: :found)).to eq([["a", "c"], ["b"]])
    end

    context "when passed no group" do
      it "sort by file size" do
        expect(File).to receive(:stat).with("a").and_return 1
        expect(File).to receive(:stat).with("b").and_return 1
        expect(File).to receive(:stat).with("c").and_return 3
        call(["a", "b", "c"], 2)
      end

      it "sorts by runtime when runtime is available" do
        expect(ParallelTests::Test::Runner).to receive(:puts).with("Using recorded test runtime")
        expect(ParallelTests::Test::Runner).to receive(:runtimes).and_return({"a" => 1, "b" => 1, "c" => 3})
        expect(call(["a", "b", "c"], 2)).to eq([["c"], ["a", "b"]])
      end

      it "sorts by filesize when there are no files" do
        expect(ParallelTests::Test::Runner).to receive(:puts).never
        expect(ParallelTests::Test::Runner).to receive(:runtimes).and_return({})
        expect(call([], 2)).to eq([[], []])
      end

      it "sorts by filesize when runtime is too little" do
        expect(ParallelTests::Test::Runner).not_to receive(:puts)
        expect(ParallelTests::Test::Runner).to receive(:runtimes).and_return(["a:1"])
        expect(File).to receive(:stat).with("a").and_return 1
        expect(File).to receive(:stat).with("b").and_return 1
        expect(File).to receive(:stat).with("c").and_return 3
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
        expect { call(["aaa"], 3, group_by: :runtime) }.to raise_error(Errno::ENOENT)
      end

      it "fails when there is too little log" do
        File.write("tmp/parallel_runtime_test.log", "xxx:123\nyyy:123\naaa:123")
        expect { call(["aaa", "bbb", "ccc"], 3, group_by: :runtime) }.to raise_error(RuntimeError)
      end

      it "groups a lot of missing files when allow-missing is high" do
        File.write("tmp/parallel_runtime_test.log", "xxx:123\nyyy:123\naaa:123")
        call(["aaa", "bbb", "ccc"], 3, group_by: :runtime, allowed_missing_percent: 80)
      end

      it "groups when there is enough log" do
        File.write("tmp/parallel_runtime_test.log", "xxx:123\nbbb:123\naaa:123")
        call(["aaa", "bbb", "ccc"], 3, group_by: :runtime)
      end

      it "groups when test name contains colons" do
        File.write("tmp/parallel_runtime_test.log", "ccc[1:2:3]:1\nbbb[1:2:3]:2\naaa[1:2:3]:3")
        expect(call(["aaa[1:2:3]", "bbb[1:2:3]", "ccc[1:2:3]"], 2, group_by: :runtime)).to match_array([["aaa[1:2:3]"], ["bbb[1:2:3]", "ccc[1:2:3]"]])
      end

      it "groups when not even statistic" do
        File.write("tmp/parallel_runtime_test.log", "aaa:1\nbbb:1\nccc:8")
        expect(call(["aaa", "bbb", "ccc"], 2, group_by: :runtime)).to match_array([["aaa", "bbb"], ["ccc"]])
      end

      it "groups with average for missing" do
        File.write("tmp/parallel_runtime_test.log", "xxx:123\nbbb:10\nccc:1")
        expect(call(["aaa", "bbb", "ccc", "ddd"], 2, group_by: :runtime)).to eq([["bbb", "ccc"], ["aaa", "ddd"]])
      end

      it "groups with unknown-runtime for missing" do
        File.write("tmp/parallel_runtime_test.log", "xxx:123\nbbb:10\nccc:1")
        expect(call(["aaa", "bbb", "ccc", "ddd"], 2, group_by: :runtime, unknown_runtime: 0.0)).to eq([["bbb"], ["aaa", "ccc", "ddd"]])
      end

      it "groups by single_process pattern and then via size" do
        expect(ParallelTests::Test::Runner).to receive(:runtimes).
          and_return({"aaa" => 5, "bbb" => 2, "ccc" => 1, "ddd" => 1})
        result = call(["aaa", "aaa2", "bbb", "ccc", "ddd"], 3, single_process: [/^a.a/], group_by: :runtime)
        expect(result).to eq([["aaa", "aaa2"], ["bbb"], ["ccc", "ddd"]])
      end

      it "groups by size and adds isolated separately" do
        skip if RUBY_PLATFORM == "java"
        expect(ParallelTests::Test::Runner).to receive(:runtimes).
          and_return({"aaa" => 0, "bbb" => 3, "ccc" => 1, "ddd" => 2})
        result = call(["aaa", "bbb", "ccc", "ddd", "eee"], 3, isolate: true, single_process: [/^aaa/], group_by: :runtime)

        isolated, *groups = result
        expect(isolated).to eq(["aaa"])
        actual = groups.map(&:to_set).to_set

        # both eee and ccs are the same size, so either can be in either group
        valid_combinations = [
          [["bbb", "eee"], ["ccc", "ddd"]].map(&:to_set).to_set,
          [["bbb", "ccc"], ["eee", "ddd"]].map(&:to_set).to_set
        ]

        expect(valid_combinations).to include(actual)
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

      expect(call(output)).to eq(['10 tests, 20 assertions, 0 failures, 0 errors','14 tests, 20 assertions, 0 failures, 0 errors'])
    end

    it "ignores color-codes" do
      output = <<EOF
10 tests, 20 assertions, 0 \e[31mfailures, 0 errors
EOF
      expect(call(output)).to eq(['10 tests, 20 assertions, 0 failures, 0 errors'])
    end
  end

  describe ".find_tests" do
    def call(*args)
      ParallelTests::Test::Runner.send(:find_tests, *args)
    end

    it "finds test in folders with appended /" do
      with_files(['b/a_test.rb']) do |root|
        expect(call(["#{root}/"]).sort).to eq([
          "#{root}/b/a_test.rb",
        ])
      end
    end

    it "finds test files nested in symlinked folders" do
      with_files(['a/a_test.rb','b/b_test.rb']) do |root|
        `ln -s #{root}/a #{root}/b/link`
        expect(call(["#{root}/b"]).sort).to eq([
          "#{root}/b/b_test.rb",
          "#{root}/b/link/a_test.rb",
        ])
      end
    end

    it "finds test files but ignores those in symlinked folders" do
      skip if RUBY_PLATFORM == "java"
      with_files(['a/a_test.rb','b/b_test.rb']) do |root|
        `ln -s #{root}/a #{root}/b/link`
        expect(call(["#{root}/b"], :symlinks => false).sort).to eq([
          "#{root}/b/b_test.rb",
        ])
      end
    end

    it "finds test files nested in different folders" do
      with_files(['a/a_test.rb','b/b_test.rb', 'c/c_test.rb']) do |root|
        expect(call(["#{root}/a", "#{root}/b"]).sort).to eq([
          "#{root}/a/a_test.rb",
          "#{root}/b/b_test.rb",
        ])
      end
    end

    it "only finds tests in folders" do
      with_files(['a/a_test.rb', 'a/test.rb', 'a/test_helper.rb']) do |root|
        expect(call(["#{root}/a"]).sort).to eq([
          "#{root}/a/a_test.rb"
        ])
      end
    end

    it "finds tests in nested folders" do
      with_files(['a/b/c/d/a_test.rb']) do |root|
        expect(call(["#{root}/a"]).sort).to eq([
          "#{root}/a/b/c/d/a_test.rb"
        ])
      end
    end

    it "does not expand paths" do
      with_files(['a/x_test.rb']) do |root|
        Dir.chdir root do
          expect(call(['a']).sort).to eq([
            "a/x_test.rb"
          ])
        end
      end
    end

    it "finds test files in folders by pattern" do
      with_files(['a/x_test.rb','a/y_test.rb','a/z_test.rb']) do |root|
        Dir.chdir root do
          expect(call(["a"], :pattern => /^a\/(y|z)_test/).sort).to eq([
            "a/y_test.rb",
            "a/z_test.rb",
          ])
        end
      end
    end

    it "finds test files in folders using suffix and overriding built in suffix" do
      with_files(['a/x_test.rb','a/y_test.rb','a/z_other.rb','a/x_different.rb']) do |root|
        Dir.chdir root do
          expect(call(["a"], :suffix => /_(test|other)\.rb$/).sort).to eq([
            "a/x_test.rb",
            "a/y_test.rb",
            "a/z_other.rb",
          ])
        end
      end
    end

    it "doesn't find bakup files with the same name as test files" do
      with_files(['a/x_test.rb','a/x_test.rb.bak']) do |root|
        expect(call(["#{root}/"])).to eq([
          "#{root}/a/x_test.rb",
        ])
      end
    end

    it "finds minispec files" do
      with_files(['a/x_spec.rb']) do |root|
        expect(call(["#{root}/"])).to eq([
          "#{root}/a/x_spec.rb",
        ])
      end
    end

    it "finds nothing if I pass nothing" do
      expect(call(nil)).to eq([])
    end

    it "finds nothing if I pass nothing (empty array)" do
      expect(call([])).to eq([])
    end

    it "keeps invalid files" do
      expect(call(['baz'])).to eq(['baz'])
    end

    it "discards duplicates" do
      expect(call(['baz','baz'])).to eq(['baz'])
    end
  end

  describe ".summarize_results" do
    def call(*args)
      ParallelTests::Test::Runner.summarize_results(*args)
    end

    it "adds results" do
      expect(call(['1 foo 3 bar','2 foo 5 bar'])).to eq('8 bars, 3 foos')
    end

    it "adds results with braces" do
      expect(call(['1 foo(s) 3 bar(s)','2 foo 5 bar'])).to eq('8 bars, 3 foos')
    end

    it "adds same results with plurals" do
      expect(call(['1 foo 3 bar','2 foos 5 bar'])).to eq('8 bars, 3 foos')
    end

    it "adds non-similar results" do
      expect(call(['1 xxx 2 yyy','1 xxx 2 zzz'])).to eq('2 xxxs, 2 yyys, 2 zzzs')
    end

    it "does not pluralize 1" do
      expect(call(['1 xxx 2 yyy'])).to eq('1 xxx, 2 yyys')
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
        expect(result).to include({
          :stdout => "2\n",
          :exit_status => 0
        })
      end
    end

    it "sets process number to '' for 0" do
      run_with_file("puts ENV['TEST_ENV_NUMBER'].inspect") do |path|
        result = call("ruby #{path}", 0, 4, {})
        expect(result).to include({
          :stdout => "\"\"\n",
          :exit_status => 0
        })
      end
    end

    it "sets process number to 1 for 0 if requested" do
      run_with_file("puts ENV['TEST_ENV_NUMBER']") do |path|
        result = call("ruby #{path}", 0, 4, first_is_1: true)
        expect(result).to include({
          :stdout => "1\n",
          :exit_status => 0
        })
      end
    end

    it 'sets PARALLEL_TEST_GROUPS so child processes know that they are being run under parallel_tests' do
      run_with_file("puts ENV['PARALLEL_TEST_GROUPS']") do |path|
        result = call("ruby #{path}", 1, 4, {})
        expect(result).to include({
          :stdout => "4\n",
          :exit_status => 0
        })
      end
    end

    it "skips reads from stdin" do
      skip "hangs on normal ruby, works on jruby" unless RUBY_PLATFORM == "java"
      run_with_file("$stdin.read; puts 123") do |path|
        result = call("ruby #{path}", 1, 2, {})
        expect(result).to include({
          :stdout => "123\n",
          :exit_status => 0
        })
      end
    end

    it "waits for process to finish" do
      run_with_file("sleep 0.5; puts 123; sleep 0.5; puts 345") do |path|
        result = call("ruby #{path}", 1, 4, {})
        expect(result).to include({
          :stdout => "123\n345\n",
          :exit_status => 0
        })
      end
    end

    it "prints output while running" do
      skip "too slow" if RUBY_PLATFORM == " java"
      run_with_file("$stdout.sync = true; puts 123; sleep 0.1; print 345; sleep 0.1; puts 567") do |path|
        received = ""
        allow($stdout).to receive(:print) do |x|
          received << x.strip
        end

        result = call("ruby #{path}", 1, 4, {})
        expect(received).to eq("123345567")
        expect(result).to include({
          :stdout => "123\n345567\n",
          :exit_status => 0
        })
      end
    end

    it "works with synced stdout" do
      run_with_file("$stdout.sync = true; puts 123; sleep 0.1; puts 345") do |path|
        result = call("ruby #{path}", 1, 4, {})
        expect(result).to include({
          :stdout => "123\n345\n",
          :exit_status => 0
        })
      end
    end

    it "does not print to stdout with :serialize_stdout" do
      run_with_file("puts 123") do |path|
        expect($stdout).not_to receive(:print)
        result = call("ruby #{path}", 1, 4, :serialize_stdout => true)
        expect(result).to include({
          :stdout => "123\n",
          :exit_status => 0
        })
      end
    end

    it "returns correct exit status" do
      run_with_file("puts 123; exit 5") do |path|
        result = call("ruby #{path}", 1, 4, {})
        expect(result).to include({
          :stdout => "123\n",
          :exit_status => 5
        })
      end
    end

    it "prints each stream to the correct stream" do
      skip "open3"
      out, err = run_with_file("puts 123 ; $stderr.puts 345 ; exit 5") do |path|
        result = call("ruby #{path}", 1, 4, {})
        expect(result).to include({
          :stdout => "123\n",
          :exit_status => 5
        })
      end
      expect(err).to eq("345\n")
    end

    it "uses a lower priority process when the nice option is used" do
      priority_cmd = "puts Process.getpriority(Process::PRIO_PROCESS, 0)"
      priority_without_nice = run_with_file(priority_cmd){ |cmd| call("ruby #{cmd}", 1, 4, {}) }.first.to_i
      priority_with_nice = run_with_file(priority_cmd){ |cmd| call("ruby #{cmd}", 1, 4, :nice => true) }.first.to_i
      expect(priority_without_nice).to be < priority_with_nice
    end

    it "returns command used" do
      run_with_file("puts 123; exit 5") do |path|
        env_vars = "TEST_ENV_NUMBER=2;export TEST_ENV_NUMBER;PARALLEL_TEST_GROUPS=4;export PARALLEL_TEST_GROUPS;"
        result = call("ruby #{path}", 1, 4, {})
        expect(result).to include({
          :command => "#{env_vars}ruby #{path}"
        })
      end
    end

    describe "rspec seed" do
      it "includes seed when provided" do
        run_with_file("puts 'Run options: --seed 555'") do |path|
          result = call("ruby #{path}", 1, 4, {})
          expect(result).to include({
            :seed => "555"
          })
        end
      end

      it "seed is nil when not provided" do
        run_with_file("puts 555") do |path|
          result = call("ruby #{path}", 1, 4, {})
          expect(result).to include({
            :seed => nil
          })
        end
      end
    end
  end

  describe ".command_with_seed" do
    def call(args)
      base = "ruby -Ilib:test test/minitest/test_minitest_unit.rb"
      result = ParallelTests::Test::Runner.command_with_seed("#{base}#{args}", 555)
      result.sub(base, '')
    end

    it "adds the randomized seed" do
      expect(call("")).to eq(" --seed 555")
    end

    it "does not duplicate seed" do
      expect(call(" --seed 123")).to eq(" --seed 555")
    end

    it "does not match strange seeds stuff" do
      expect(call(" --seed 123asdasd")).to eq(" --seed 123asdasd --seed 555")
    end

    it "does not match non seeds" do
      expect(call(" --seedling 123")).to eq(" --seedling 123 --seed 555")
    end
  end
end
