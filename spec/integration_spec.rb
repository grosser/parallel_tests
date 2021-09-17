# frozen_string_literal: true
require 'spec_helper'

describe 'CLI' do
  before do
    FileUtils.remove_dir(folder, true)
  end

  after do
    FileUtils.remove_dir(folder, true)
  end

  def folder
    "/tmp/parallel_tests_tests"
  end

  def write(file, content)
    path = "#{folder}/#{file}"
    ensure_folder File.dirname(path)
    File.open(path, 'w') { |f| f.write content }
    path
  end

  def read(file)
    File.read "#{folder}/#{file}"
  end

  def bin_folder
    "#{__dir__}/../bin"
  end

  def executable(options = {})
    "ruby #{bin_folder}/parallel_#{options[:type] || 'test'}"
  end

  def ensure_folder(folder)
    FileUtils.mkpath(folder) unless File.exist?(folder)
  end

  def run_tests(test_folder, options = {})
    ensure_folder folder
    processes = "-n #{options[:processes] || 2}" unless options[:processes] == false
    command = "#{executable(options)} #{test_folder} #{processes} #{options[:add]}"
    result = ''
    Dir.chdir(folder) do
      env = options[:export] || {}
      IO.popen(env, command, err: [:child, :out]) do |io|
        yield(io) if block_given?
        result = io.read
      end
    end

    raise "FAILED #{command}\n#{result}" if $?.success? == !!options[:fail]
    result
  end

  def self.it_runs_the_default_folder_if_it_exists(type, test_folder)
    it "runs the default folder if it exists" do
      full_path_to_test_folder = File.join(folder, test_folder)
      ensure_folder full_path_to_test_folder
      results = run_tests("", fail: false, type: type)
      expect(results).to_not include("Pass files or folders to run")

      FileUtils.remove_dir(full_path_to_test_folder, true)
      results = run_tests("", fail: true, type: type)
      expect(results).to include("Pass files or folders to run")
    end
  end

  let(:printed_commands) { /specs? per process\nbundle exec rspec/ }
  let(:printed_rerun) { "run the group again:\n\nbundle exec rspec" }

  context "running tests sequentially" do
    it "exits with 0 when each run is successful" do
      run_tests "spec", type: 'rspec', fail: 0
    end

    it "exits with 1 when a test run fails" do
      write 'spec/xxx2_spec.rb', 'describe("it"){it("should"){ expect(true).to be false }}'
      run_tests "spec", type: 'rspec', fail: 1
    end

    it "exits with 1 even when the test run exits with a different status" do
      write 'spec/xxx2_spec.rb', <<~SPEC
        RSpec.configure { |c| c.failure_exit_code = 99 }
        describe("it"){it("should"){ expect(true).to be false }}
      SPEC

      run_tests "spec", type: 'rspec', fail: 1
    end

    it "exits with the highest exit status" do
      write 'spec/xxx2_spec.rb', <<~SPEC
        RSpec.configure { |c| c.failure_exit_code = 99 }
        describe("it"){it("should"){ expect(true).to be false }}
      SPEC

      run_tests "spec", type: 'rspec', add: "--highest-exit-status", fail: 99
    end
  end

  it "runs tests in parallel" do
    write 'spec/xxx_spec.rb', 'describe("it"){it("should"){puts "TEST1"}}'
    write 'spec/xxx2_spec.rb', 'describe("it"){it("should"){puts "TEST2"}}'
    # set processes to false so we verify empty groups are discarded by default
    result = run_tests "spec", type: 'rspec', processes: 4

    # test ran and gave their puts
    expect(result).to include('TEST1')
    expect(result).to include('TEST2')

    # all results present
    expect(result).to include_exactly_times('1 example, 0 failure', 2) # 2 results
    expect(result).to include_exactly_times('2 examples, 0 failures', 1) # 1 summary
    expect(result).to include_exactly_times(/Finished in \d+(\.\d+)? seconds/, 2)
    expect(result).to include_exactly_times(/Took \d+ seconds/, 1) # parallel summary

    # verify empty groups are discarded. if retained then it'd say 4 processes for 2 specs
    expect(result).to include '2 processes for 2 specs, ~ 1 spec per process'
  end

  context "running test in parallel" do
    it "exits with 0 when each run is successful" do
      run_tests "spec", type: 'rspec', processes: 4, fail: 0
    end

    it "exits with 1 when a test run fails" do
      write 'spec/xxx2_spec.rb', 'describe("it"){it("should"){ expect(true).to be false }}'
      run_tests "spec", type: 'rspec', processes: 4, fail: 1
    end

    it "exits with 1 even when the test run exits with a different status" do
      write 'spec/xxx2_spec.rb', <<~SPEC
        RSpec.configure { |c| c.failure_exit_code = 99 }
        describe("it"){it("should"){ expect(true).to be false }}
      SPEC

      run_tests "spec", type: 'rspec', processes: 4, fail: 1
    end

    it "exits with the highest exit status" do
      write 'spec/xxx2_spec.rb', <<~SPEC
        RSpec.configure { |c| c.failure_exit_code = 99 }
        describe("it"){it("should"){ expect(true).to be false }}
      SPEC

      run_tests "spec", type: 'rspec', processes: 4, add: "--highest-exit-status", fail: 99
    end
  end

  # Uses `Process.kill` under the hood, which on Windows doesn't work as expected. It kills all process group instead of just one process.
  describe "--fail-fast", unless: Gem.win_platform? do
    def run_tests(test_option: nil)
      super(
        "spec",
        fail: true,
        type: 'rspec',
        processes: 2,
        # group-by + order for stable execution ... doc and verbose to ease debugging
        add: "--group-by found --verbose --fail-fast --test-options '--format doc --order defined #{test_option}'"
      )
    end

    before do
      write 'spec/xxx1_spec.rb', 'describe("T1"){it("E1"){puts "YE" + "S"; sleep 0.5; expect(1).to eq(2)}}' # group 1 executed
      write 'spec/xxx2_spec.rb', 'describe("T2"){it("E2"){sleep 1; puts "OK"}}' # group 2 executed
      write 'spec/xxx3_spec.rb', 'describe("T3"){it("E3"){puts "NO3"}}' # group 1 skipped
      write 'spec/xxx4_spec.rb', 'describe("T4"){it("E4"){puts "NO4"}}' # group 2 skipped
      write 'spec/xxx5_spec.rb', 'describe("T5"){it("E5"){puts "NO5"}}' # group 1 skipped
      write 'spec/xxx6_spec.rb', 'describe("T6"){it("E6"){puts "NO6"}}' # group 2 skipped
    end

    it "can fail fast on a single test" do
      result = run_tests(test_option: "--fail-fast")

      expect(result).to include_exactly_times("YES", 1)
      expect(result).to include_exactly_times("OK", 1) # is allowed to finish but no new test is started after
      expect(result).to_not include("NO")

      expect(result).to include_exactly_times('1 example, 1 failure', 1) # rspec group 1
      expect(result).to include_exactly_times('1 example, 0 failure', 1) # rspec group 2
      expect(result).to include_exactly_times('2 examples, 1 failure', 1) # parallel_rspec summary

      expect(result).to include '2 processes for 6 specs, ~ 3 specs per process'
    end

    it "can fail fast on a single group" do
      result = run_tests

      expect(result).to include_exactly_times("YES", 1)
      expect(result).to include_exactly_times("OK", 1) # is allowed to finish but no new test is started after
      expect(result).to include_exactly_times("NO", 2)

      expect(result).to include_exactly_times('3 examples, 1 failure', 1) # rspec group 1
      expect(result).to include_exactly_times('1 example, 0 failure', 1) # rspec group 2
      expect(result).to include_exactly_times('4 examples, 1 failure', 1) # parallel_rspec summary

      expect(result).to include '2 processes for 6 specs, ~ 3 specs per process'
    end
  end

  it "runs tests which outputs accented characters" do
    write "spec/xxx_spec.rb", "#encoding: utf-8\ndescribe('it'){it('should'){puts 'Byłem tu'}}"
    result = run_tests "spec", type: 'rspec'
    # test ran and gave their puts
    expect(result).to include('Byłem tu')
  end

  it "respects default encoding when reading child stdout" do
    write 'test/xxx_test.rb', <<-EOF
      require 'test/unit'
      class XTest < Test::Unit::TestCase
        def test_unicode
          raise '¯\\_(ツ)_/¯'
        end
      end
    EOF

    # Need to tell Ruby to default to utf-8 to simulate environments where
    # this is set. (Otherwise, it defaults to nil and the undefined conversion
    # issue doesn't come up.)
    result = run_tests('test', fail: true, export: { 'RUBYOPT' => 'Eutf-8:utf-8' })
    expect(result).to include('¯\_(ツ)_/¯')
  end

  it "does not run any tests if there are none" do
    write 'spec/xxx_spec.rb', '1'
    result = run_tests "spec", type: 'rspec'
    expect(result).to include('No examples found')
    expect(result).to include('Took')
  end

  it "shows command and rerun with --verbose" do
    write 'spec/xxx_spec.rb', 'describe("it"){it("should"){puts "TEST1"}}'
    write 'spec/xxx2_spec.rb', 'describe("it"){it("should"){expect(1).to eq(2)}}'
    result = run_tests "spec --verbose", type: 'rspec', fail: true
    expect(result).to match printed_commands
    expect(result).to include printed_rerun
    expect(result).to include "bundle exec rspec spec/xxx_spec.rb"
    expect(result).to include "bundle exec rspec spec/xxx2_spec.rb"
  end

  it "shows only rerun with --verbose-rerun-command" do
    write 'spec/xxx_spec.rb', 'describe("it"){it("should"){expect(1).to eq(2)}}'
    result = run_tests "spec --verbose-rerun-command", type: 'rspec', fail: true
    expect(result).to include printed_rerun
    expect(result).to_not match printed_commands
  end

  it "shows only process with --verbose-process-command" do
    write 'spec/xxx_spec.rb', 'describe("it"){it("should"){expect(1).to eq(2)}}'
    result = run_tests "spec --verbose-process-command", type: 'rspec', fail: true
    expect(result).to_not include printed_rerun
    expect(result).to match printed_commands
  end

  it "fails when tests fail" do
    write 'spec/xxx_spec.rb', 'describe("it"){it("should"){puts "TEST1"}}'
    write 'spec/xxx2_spec.rb', 'describe("it"){it("should"){expect(1).to eq(2)}}'
    result = run_tests "spec", fail: true, type: 'rspec'

    expect(result).to include_exactly_times('1 example, 1 failure', 1)
    expect(result).to include_exactly_times('1 example, 0 failure', 1)
    expect(result).to include_exactly_times('2 examples, 1 failure', 1)
  end

  it "can serialize stdout" do
    write 'spec/xxx_spec.rb', '5.times{describe("it"){it("should"){sleep 0.01; puts "TEST1"}}}'
    write 'spec/xxx2_spec.rb', 'sleep 0.01; 5.times{describe("it"){it("should"){sleep 0.01; puts "TEST2"}}}'
    result = run_tests "spec", type: 'rspec', add: "--serialize-stdout"

    expect(result).not_to match(/TEST1.*TEST2.*TEST1/m)
    expect(result).not_to match(/TEST2.*TEST1.*TEST2/m)
  end

  it "can show simulated output when serializing stdout" do
    write 'spec/xxx_spec.rb', 'describe("it"){it("should"){sleep 0.5; puts "TEST1"}}'
    write 'spec/xxx2_spec.rb', 'describe("it"){it("should"){sleep 1; puts "TEST2"}}'
    result = run_tests "spec", type: 'rspec', add: "--serialize-stdout", export: { 'PARALLEL_TEST_HEARTBEAT_INTERVAL' => '0.01' }
    expect(result).to match(/\.{4}.*TEST1.*\.{4}.*TEST2/m)
  end

  it "can show simulated output preceded by command when serializing stdout with verbose option" do
    write 'spec/xxx_spec.rb', 'describe("it"){it("should"){sleep 1.5; puts "TEST1"}}'
    result = run_tests "spec --verbose", type: 'rspec', add: "--serialize-stdout", export: { 'PARALLEL_TEST_HEARTBEAT_INTERVAL' => '0.02' }
    expect(result).to match(/\.{5}.*\nbundle exec rspec spec\/xxx_spec\.rb\n.*^TEST1/m)
  end

  it "can serialize stdout and stderr" do
    write 'spec/xxx_spec.rb', '5.times{describe("it"){it("should"){sleep 0.01; $stderr.puts "errTEST1"; puts "TEST1"}}}'
    write 'spec/xxx2_spec.rb', 'sleep 0.01; 5.times{describe("it"){it("should"){sleep 0.01; $stderr.puts "errTEST2"; puts "TEST2"}}}'
    result = run_tests "spec", type: 'rspec', add: "--serialize-stdout --combine-stderr"

    expect(result).not_to match(/TEST1.*TEST2.*TEST1/m)
    expect(result).not_to match(/TEST2.*TEST1.*TEST2/m)
  end

  context "with given commands" do
    it "can exec given commands with ENV['TEST_ENV_NUMBER']" do
      result = `#{executable} -e 'ruby -e "print ENV[:TEST_ENV_NUMBER.to_s].to_i"' -n 4`
      expect(result.gsub('"', '').split('').sort).to eq(['0', '2', '3', '4'])
    end

    it "can exec given command non-parallel" do
      result = `#{executable} -e 'ruby -e "sleep(rand(10)/100.0); puts ENV[:TEST_ENV_NUMBER.to_s].inspect"' -n 4 --non-parallel`
      expect(result.split(/\n+/)).to eq(['""', '"2"', '"3"', '"4"'])
    end

    it "can exec given command with a restricted set of groups" do
      result = `#{executable} -e 'ruby -e "print ENV[:TEST_ENV_NUMBER.to_s].to_i"' -n 4 --only-group 1,3`
      expect(result.gsub('"', '').split('').sort).to eq(['0', '3'])
    end

    it "can serialize stdout" do
      result = `#{executable} -e 'ruby -e "5.times{sleep 0.01;puts ENV[:TEST_ENV_NUMBER.to_s].to_i;STDOUT.flush}"' -n 2 --serialize-stdout`
      expect(result).not_to match(/0.*2.*0/m)
      expect(result).not_to match(/2.*0.*2/m)
    end

    it "exists with success if all sub-processes returned success" do
      expect(system("#{executable} -e 'cat /dev/null' -n 4")).to eq(true)
    end

    it "exists with failure if any sub-processes returned failure" do
      expect(system("#{executable} -e 'test -e xxxx' -n 4")).to eq(false)
    end
  end

  it "runs through parallel_rspec" do
    version = `#{executable} -v`
    expect(`ruby #{bin_folder}/parallel_rspec -v`).to eq(version)
  end

  it "runs through parallel_cucumber" do
    version = `#{executable} -v`
    expect(`ruby #{bin_folder}/parallel_cucumber -v`).to eq(version)
  end

  it "runs through parallel_spinach" do
    version = `#{executable} -v`
    expect(`ruby #{bin_folder}/parallel_spinach -v`).to eq(version)
  end

  it "runs with --group-by found" do
    # it only tests that it does not blow up, as it did before fixing...
    write "spec/x1_spec.rb", "puts 'TEST111'"
    run_tests "spec", type: 'rspec', add: '--group-by found'
  end

  it "runs in parallel" do
    2.times do |i|
      write "spec/xxx#{i}_spec.rb", 'STDOUT.sync = true; describe("it") { it("should"){ puts "START"; sleep 1; puts "END" } }'
    end
    result = run_tests("spec", processes: 2, type: 'rspec')
    expect(result.scan(/START|END/)).to eq(["START", "START", "END", "END"])
  end

  it "disables spring so correct database is used" do
    write "spec/xxx_spec.rb", 'puts "SPRING: #{ENV["DISABLE_SPRING"]}"'
    result = run_tests("spec", processes: 2, type: 'rspec')
    expect(result).to include "SPRING: 1"
  end

  it "can enable spring" do
    write "spec/xxx_spec.rb", 'puts "SPRING: #{ENV["DISABLE_SPRING"]}"'
    result = run_tests("spec", processes: 2, type: 'rspec', export: { "DISABLE_SPRING" => "0" })
    expect(result).to include "SPRING: 0"
  end

  it "runs with files that have spaces" do
    write "test/xxx _test.rb", 'puts "TEST_SUCCESS"'
    result = run_tests("test", processes: 2, type: 'test')
    expect(result).to include "TEST_SUCCESS"
  end

  it "uses relative paths for easy copying" do
    write "test/xxx_test.rb", 'puts "Test output: YES"'
    result = run_tests("test", processes: 2, type: 'test', add: '--verbose')
    expect(result).to include "Test output: YES"
    expect(result).to include "[test/xxx_test.rb]"
    expect(result).not_to include Dir.pwd
  end

  it "can run with given files" do
    write "spec/x1_spec.rb", "puts 'TEST111'"
    write "spec/x2_spec.rb", "puts 'TEST222'"
    write "spec/x3_spec.rb", "puts 'TEST333'"
    result = run_tests "spec/x1_spec.rb spec/x3_spec.rb", type: 'rspec'
    expect(result).to include('TEST111')
    expect(result).to include('TEST333')
    expect(result).not_to include('TEST222')
  end

  it "can run with test-options" do
    write "spec/x1_spec.rb", "111"
    write "spec/x2_spec.rb", "111"
    result = run_tests "spec", add: "--test-options ' --version'", processes: 2, type: 'rspec'
    expect(result).to match(/\d+\.\d+\.\d+.*\d+\.\d+\.\d+/m) # prints version twice
  end

  it "runs with PARALLEL_TEST_PROCESSORS processes" do
    skip if RUBY_PLATFORM == "java" # execution expired issue on JRuby
    processes = 5
    processes.times do |i|
      write "spec/x#{i}_spec.rb", "puts %{ENV-\#{ENV['TEST_ENV_NUMBER']}-}"
    end
    result = run_tests(
      "spec", export: { "PARALLEL_TEST_PROCESSORS" => processes.to_s }, processes: processes, type: 'rspec'
    )
    expect(result.scan(/ENV-.?-/)).to match_array(["ENV--", "ENV-2-", "ENV-3-", "ENV-4-", "ENV-5-"])
  end

  it "filters test by given pattern and relative paths" do
    write "spec/x_spec.rb", "puts 'TESTXXX'"
    write "spec/y_spec.rb", "puts 'TESTYYY'"
    write "spec/z_spec.rb", "puts 'TESTZZZ'"
    result = run_tests "spec", add: "-p '^spec/(x|z)'", type: "rspec"
    expect(result).to include('TESTXXX')
    expect(result).not_to include('TESTYYY')
    expect(result).to include('TESTZZZ')
  end

  it "excludes test by given pattern and relative paths" do
    write "spec/x_spec.rb", "puts 'TESTXXX'"
    write "spec/acceptance/y_spec.rb", "puts 'TESTYYY'"
    write "spec/integration/z_spec.rb", "puts 'TESTZZZ'"
    result = run_tests "spec", add: "--exclude-pattern 'spec/(integration|acceptance)'", type: "rspec"
    expect(result).to include('TESTXXX')
    expect(result).not_to include('TESTYYY')
    expect(result).not_to include('TESTZZZ')
  end

  it "can wait_for_other_processes_to_finish" do
    skip if RUBY_PLATFORM == "java" # just too slow ...
    write "test/a_test.rb", "require 'parallel_tests'; sleep 0.5 ; ParallelTests.wait_for_other_processes_to_finish; puts 'OutputA'"
    write "test/b_test.rb", "sleep 1; puts 'OutputB'"
    write "test/c_test.rb", "sleep 1.5; puts 'OutputC'"
    write "test/d_test.rb", "sleep 2; puts 'OutputD'"
    actual = run_tests("test", processes: 4).scan(/Output[ABCD]/)
    actual_sorted = [*actual[0..2].sort, actual[3]]
    expect(actual_sorted).to match(["OutputB", "OutputC", "OutputD", "OutputA"])
  end

  it "can run only a single group" do
    skip if RUBY_PLATFORM == "java" # just too slow ...
    write "test/long_test.rb", "puts 'this is a long test'"
    write "test/short_test.rb", "puts 'short test'"

    group_1_result = run_tests("test", processes: 2, add: '--only-group 1')
    expect(group_1_result).to include("this is a long test")
    expect(group_1_result).not_to include("short test")

    group_2_result = run_tests("test", processes: 2, add: '--only-group 2')
    expect(group_2_result).not_to include("this is a long test")
    expect(group_2_result).to include("short test")
  end

  it "shows nice --help" do
    result = run_tests "--help"
    expect(
      result[/(.*)How many processes/, 1].size
    ).to(
      eq(result[/( +)found /, 1].size),
      "Multiline option description must align with regular option description"
    )
  end

  it "can run with uncommon file names" do
    skip if RUBY_PLATFORM == "java" # just too slow ...
    write "test/long ( stuff ) _test.rb", "puts 'hey'"
    expect(run_tests("test", processes: 2)).to include("hey")
  end

  context "RSpec" do
    it_runs_the_default_folder_if_it_exists "rspec", "spec"

    it "captures seed with random failures with --verbose" do
      write 'spec/xxx_spec.rb', 'describe("it"){it("should"){puts "TEST1"}}'
      write 'spec/xxx2_spec.rb', 'describe("it"){it("should"){1.should == 2}}'
      result = run_tests "spec --verbose", add: "--test-options '--seed 1234'", fail: true, type: 'rspec'
      expect(result).to include("Randomized with seed 1234")
      expect(result).to include("bundle exec rspec spec/xxx2_spec.rb --seed 1234")
    end
  end

  context "Test::Unit" do
    it "runs" do
      write "test/x1_test.rb", "require 'test/unit'; class XTest < Test::Unit::TestCase; def test_xxx; end; end"
      result = run_tests("test")
      expect(result).to include('1 test')
    end

    it "passes test options" do
      write "test/x1_test.rb", "require 'test/unit'; class XTest < Test::Unit::TestCase; def test_xxx; end; end"
      result = run_tests("test", add: '--test-options "-v"')
      expect(result).to include('test_xxx') # verbose output of every test
    end

    it_runs_the_default_folder_if_it_exists "test", "test"
  end

  context "Cucumber" do
    before do
      write "features/steps/a.rb", "
        Given('I print TEST_ENV_NUMBER'){ puts \"YOUR TEST ENV IS \#{ENV['TEST_ENV_NUMBER']}!\" }
        And('I sleep a bit'){ sleep 0.5 }
        And('I pass'){ true }
        And('I fail'){ fail }
      "
    end

    it "runs tests which outputs accented characters" do
      write "features/good1.feature", "Feature: xxx\n  Scenario: xxx\n    Given I print accented characters"
      write "features/steps/a.rb", "#encoding: utf-8\nGiven('I print accented characters'){ puts \"I tu też\" }"
      result = run_tests "features", type: "cucumber", add: '--pattern good'
      expect(result).to include('I tu też')
    end

    it "passes TEST_ENV_NUMBER when running with pattern (issue #86)" do
      write "features/good1.feature", "Feature: xxx\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER"
      write "features/good2.feature", "Feature: xxx\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER"
      write "features/b.feature", "Feature: xxx\n  Scenario: xxx\n    Given I FAIL"
      write "features/steps/a.rb", "Given('I print TEST_ENV_NUMBER'){ puts \"YOUR TEST ENV IS \#{ENV['TEST_ENV_NUMBER']}!\" }"

      result = run_tests "features", type: "cucumber", add: '--pattern good'

      expect(result).to include('YOUR TEST ENV IS 2!')
      expect(result).to include('YOUR TEST ENV IS !')
      expect(result).not_to include('I FAIL')
    end

    it "writes a runtime log" do
      skip "TODO find out why this fails" if RUBY_PLATFORM == "java"

      log = "tmp/parallel_runtime_cucumber.log"
      write(log, "x")
      2.times do |i|
        # needs sleep so that runtime loggers dont overwrite each other initially
        write "features/good#{i}.feature", "Feature: xxx\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER\n    And I sleep a bit"
      end
      run_tests "features", type: "cucumber"
      expect(read(log).gsub(/\.\d+/, '').split("\n")).to match_array(["features/good0.feature:0", "features/good1.feature:0"])
    end

    it "runs each feature once when there are more processes then features (issue #89)" do
      2.times do |i|
        write "features/good#{i}.feature", "Feature: xxx\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER"
      end
      result = run_tests "features", type: "cucumber", add: '-n 3'
      expect(result.scan(/YOUR TEST ENV IS \d?!/).sort).to eq(["YOUR TEST ENV IS !", "YOUR TEST ENV IS 2!"])
    end

    it_runs_the_default_folder_if_it_exists "cucumber", "features"

    it "collates failing scenarios" do
      write "features/pass.feature", "Feature: xxx\n  Scenario: xxx\n    Given I pass"
      write "features/fail1.feature", "Feature: xxx\n  Scenario: xxx\n    Given I fail"
      write "features/fail2.feature", "Feature: xxx\n  Scenario: xxx\n    Given I fail"
      results = run_tests "features", processes: 3, type: "cucumber", fail: true

      failing_scenarios = if Gem.win_platform?
        ["cucumber features/fail1.feature:2 # Scenario: xxx", "cucumber features/fail2.feature:2 # Scenario: xxx"]
      else
        ["cucumber features/fail2.feature:2 # Scenario: xxx", "cucumber features/fail1.feature:2 # Scenario: xxx"]
      end

      expect(results).to include <<-EOF.gsub('        ', '')
        Failing Scenarios:
        #{failing_scenarios[0]}
        #{failing_scenarios[1]}

        3 scenarios (2 failed, 1 passed)
        3 steps (2 failed, 1 passed)
      EOF
    end

    it "groups by scenario" do
      write "features/long.feature", <<-EOS
        Feature: xxx
          Scenario: xxx
            Given I print TEST_ENV_NUMBER

          Scenario: xxx
            Given I print TEST_ENV_NUMBER

          Scenario Outline: xxx
            Given I print TEST_ENV_NUMBER

          Examples:
            | num |
            | one |
            | two |
      EOS
      result = run_tests "features", type: "cucumber", add: "--group-by scenarios"
      expect(result).to include("2 processes for 4 scenarios")
    end

    it "groups by step" do
      write "features/good1.feature", "Feature: xxx\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER"
      write "features/good2.feature", "Feature: xxx\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER"

      result = run_tests "features", type: "cucumber", add: '--group-by steps'

      expect(result).to include("2 processes for 2 features")
    end

    it "captures seed with random failures with --verbose" do
      write "features/good1.feature", "Feature: xxx\n  Scenario: xxx\n    Given I fail"
      result = run_tests "features --verbose", type: "cucumber", add: '--test-options "--order random:1234"', fail: true
      expect(result).to include("Randomized with seed 1234")
      expect(result).to match(%r{bundle exec cucumber "?features/good1.feature"? --order random:1234})
    end
  end

  context "Spinach" do
    before do
      write "features/steps/a.rb", <<-RUBY.strip_heredoc
        class A < Spinach::FeatureSteps
          Given 'I print TEST_ENV_NUMBER' do
            puts "YOUR TEST ENV IS \#{ENV['TEST_ENV_NUMBER']}!"
          end
          And 'I sleep a bit' do
            sleep 0.2
          end
        end
      RUBY
    end

    it "runs tests which outputs accented characters" do
      write "features/good1.feature", "Feature: a\n  Scenario: xxx\n    Given I print accented characters"
      write "features/steps/a.rb", "#encoding: utf-8\nclass A < Spinach::FeatureSteps\nGiven 'I print accented characters' do\n  puts \"I tu też\" \n  end\nend"
      result = run_tests "features", type: "spinach", add: 'features/good1.feature' # , :add => '--pattern good'
      expect(result).to include('I tu też')
    end

    it "passes TEST_ENV_NUMBER when running with pattern (issue #86)" do
      write "features/good1.feature", "Feature: a\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER"
      write "features/good2.feature", "Feature: a\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER"
      write "features/b.feature", "Feature: b\n  Scenario: xxx\n    Given I FAIL" # Expect this not to be run

      result = run_tests "features", type: "spinach", add: '--pattern good'

      expect(result).to include('YOUR TEST ENV IS 2!')
      expect(result).to include('YOUR TEST ENV IS !')
      expect(result).not_to include('I FAIL')
    end

    it "writes a runtime log" do
      skip 'not yet implemented -- custom runtime logging'
      log = "tmp/parallel_runtime_spinach.log"
      write(log, "x")

      2.times do |i|
        # needs sleep so that runtime loggers dont overwrite each other initially
        write "features/good#{i}.feature", "Feature: A\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER\n    And I sleep a bit"
      end
      run_tests "features", type: "spinach"
      expect(read(log).gsub(/\.\d+/, '').split("\n")).to match_array(["features/good0.feature:0", "features/good1.feature:0"])
    end

    it "runs each feature once when there are more processes then features (issue #89)" do
      2.times do |i|
        write "features/good#{i}.feature", "Feature: A\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER\n"
      end
      result = run_tests "features", type: "spinach", add: '-n 3'
      expect(result.scan(/YOUR TEST ENV IS \d?!/).sort).to eq(["YOUR TEST ENV IS !", "YOUR TEST ENV IS 2!"])
    end

    it_runs_the_default_folder_if_it_exists "spinach", "features"
  end

  describe "graceful shutdown" do
    # Process.kill on Windows doesn't work as expected. It kills all process group instead of just one process.
    it "passes on int signal to child processes", unless: Gem.win_platform? do
      timeout = 2
      write "spec/test_spec.rb", "sleep #{timeout}; describe { specify { 'Should not get here' }; specify { p 'Should not get here either'} }"
      pid = nil
      Thread.new { sleep timeout - 0.5; Process.kill("INT", pid) }
      result = run_tests("spec", processes: 2, type: 'rspec', fail: true) { |io| pid = io.pid }

      expect(result).to include("RSpec is shutting down")
      expect(result).to_not include("Should not get here")
      expect(result).to_not include("Should not get here either")
    end

    # Process.kill on Windows doesn't work as expected. It kills all process group instead of just one process.
    it "exits immediately if another int signal is received", unless: Gem.win_platform? do
      timeout = 2
      write "spec/test_spec.rb", "describe { specify { sleep #{timeout}; p 'Should not get here'} }"
      pid = nil
      Thread.new { sleep timeout - 0.5; Process.kill("INT", pid) }
      Thread.new { sleep timeout - 0.3; Process.kill("INT", pid) }
      result = run_tests("spec", processes: 2, type: 'rspec', fail: false) { |io| pid = io.pid }
      expect(result).to_not include("Should not get here")
    end
  end
end
