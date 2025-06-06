# frozen_string_literal: true
require "spec_helper"
require "parallel_tests/cli"
require "parallel_tests/rspec/runner"

describe ParallelTests::CLI do
  subject { ParallelTests::CLI.new }

  describe "#parse_options" do
    let(:defaults) { { files: ["test"] } }

    def call(*args)
      subject.send(:parse_options!, *args)
    end

    it "does not fail without file" do
      expect(subject).not_to receive(:abort)
      call(["-n3", "-t", "rspec"])
    end

    it "cleanups file paths" do
      expect(call(["./test"])).to eq(defaults)
    end

    it "parses execute" do
      expect(call(["--exec", "echo"])).to eq(execute: ["echo"])
    end

    it "parses execute arguments" do
      expect(call(["test", "--exec-args", "echo"])).to eq(defaults.merge(execute_args: ["echo"]))
    end

    it "parses excludes pattern" do
      expect(call(["test", "--exclude-pattern", "spec/"])).to eq(defaults.merge(exclude_pattern: /spec\//))
    end

    it "parses regular count" do
      expect(call(["test", "-n3"])).to eq(defaults.merge(count: 3))
    end

    it "parses count 0 as non-parallel" do
      expect(call(["test", "-n0"])).to eq(defaults.merge(non_parallel: true))
    end

    it "parses non-parallel as non-parallel" do
      expect(call(["test", "--non-parallel"])).to eq(defaults.merge(non_parallel: true))
    end

    it "finds the correct type when multiple are given" do
      call(["test", "--type", "test", "-t", "rspec"])
      expect(subject.instance_variable_get(:@runner)).to eq(ParallelTests::RSpec::Runner)
    end

    it "parses nice as nice" do
      expect(call(["test", "--nice"])).to eq(defaults.merge(nice: true))
    end

    it "parses --verbose" do
      expect(call(["test", "--verbose"])).to eq(defaults.merge(verbose: true))
    end

    it "parses --verbose-command" do
      expect(call(['test', '--verbose-command'])).to eq(
        defaults.merge(verbose_process_command: true, verbose_rerun_command: true)
      )
    end

    it "parses --verbose-process-command" do
      expect(call(['test', '--verbose-process-command'])).to eq(
        defaults.merge(verbose_process_command: true)
      )
    end

    it "parses --verbose-rerun-command" do
      expect(call(['test', '--verbose-rerun-command'])).to eq(
        defaults.merge(verbose_rerun_command: true)
      )
    end

    it "parses --failure-exit-code" do
      expect(call(["test", "--failure-exit-code", "42"])).to eq(defaults.merge(failure_exit_code: 42))
    end

    it "parses --quiet" do
      expect(call(["test", "--quiet"])).to eq(defaults.merge(quiet: true))
    end

    it "fails if both --verbose and --quiet are present" do
      expect { call(["test", "--verbose", "--quiet"]) }.to raise_error(RuntimeError)
    end

    it "parses --suffix" do
      expect(call(["test", "--suffix", "_(test|spec).rb$"])).to eq(defaults.merge(suffix: /_(test|spec).rb$/))
    end

    it "parses --first-is-1" do
      expect(call(["test", "--first-is-1"]))
        .to eq(defaults.merge(first_is_1: true))
    end

    it "parses allow-duplicates" do
      expect(call(["test", "--allow-duplicates"])).to eq(defaults.merge(allow_duplicates: true))
    end

    context "parse only-group" do
      it "group_by should be set to filesize" do
        expect(call(["test", "--only-group", '1'])).to eq(defaults.merge(only_group: [1], group_by: :filesize))
      end

      it "allows runtime" do
        expect(call(["test", "--only-group", '1', '--group-by', 'runtime'])).to eq(defaults.merge(only_group: [1], group_by: :runtime))
      end

      it "raise error when group_by isn't filesize" do
        expect  do
          call(["test", "--only-group", '1', '--group-by', 'steps'])
        end.to raise_error(RuntimeError)
      end

      it "with multiple groups" do
        expect(call(["test", "--only-group", '4,5'])).to eq(defaults.merge(only_group: [4, 5], group_by: :filesize))
      end

      it "with a single group" do
        expect(call(["test", "--only-group", '4'])).to eq(defaults.merge(only_group: [4], group_by: :filesize))
      end
    end

    context "single and isolate" do
      it "single_process should be an array of patterns" do
        expect(call(["test", "--single", '1'])).to eq(defaults.merge(single_process: [/1/]))
      end

      it "single_process should be an array of patterns" do
        expect(call(["test", "--single", '1', "--single", '2'])).to eq(defaults.merge(single_process: [/1/, /2/]))
      end

      it "isolate should set isolate_count defaults" do
        expect(call(["test", "--single", '1', "--isolate"])).to eq(defaults.merge(single_process: [/1/], isolate: true))
      end

      it "isolate_n should set isolate_count and turn on isolate" do
        expect(call(["test", "-n", "3", "--single", '1', "--isolate-n", "2"])).to eq(
          defaults.merge(count: 3, single_process: [/1/], isolate_count: 2)
        )
      end
    end

    context "specify groups" do
      it "groups can be just one string" do
        expect(call(["test", "--specify-groups", 'test'])).to eq(defaults.merge(specify_groups: 'test'))
      end

      it "groups can be a string separated by commas and pipes" do
        expect(call(["test", "--specify-groups", 'test1,test2|test3'])).to eq(defaults.merge(specify_groups: 'test1,test2|test3'))
      end
    end

    context "when the -- option separator is used" do
      it "interprets arguments as files/directories" do
        expect(call(['--', 'test'])).to eq(files: ['test'])
        expect(call(['--', './test'])).to eq(files: ['test'])
        expect(call(['--', 'test', 'test2'])).to eq(files: ['test', 'test2'])
        expect(call(['--', '--foo', 'test'])).to eq(files: ['--foo', 'test'])
        expect(call(['--', 'test', '--foo', 'test2'])).to eq(files: ['test', '--foo', 'test2'])
      end

      it "correctly handles arguments with spaces" do
        expect(call(['--', 'file name with space'])).to eq(files: ['file name with space'])
      end

      context "when the -o options has also been given" do
        it "merges the options together" do
          expect(call(['-o', "'-f'", '--', 'test', '--foo', 'test2'])).to eq(files: ['test', '--foo', 'test2'], test_options: ['-f'])
        end
      end

      context "when a second -- option separator is used" do
        it "interprets the first set as test_options" do
          expect(call(['--', '-r', 'foo', '--', 'test'])).to eq(files: ['test'], test_options: ['-r', 'foo'])
          expect(call(['--', '-r', 'foo', '--', 'test', 'test2'])).to eq(files: ['test', 'test2'], test_options: ['-r', 'foo'])
          expect(call(['--', '-r', 'foo', '-o', 'out.log', '--', 'test', 'test2'])).to eq(files: ['test', 'test2'], test_options: ['-r', 'foo', '-o', 'out.log'])
        end

        context "when existing test_options have previously been given" do
          it "appends the new options" do
            expect(call(['-o', '-f', '--', '-r', 'foo.rb', '--', 'test'])).to eq(files: ['test'], test_options: ['-f', '-r', 'foo.rb'])
          end
          it "correctly handles argument values with spaces" do
            argv = ["-o 'path with spaces1'", '--', '--out', 'path with spaces2', '--', 'foo']
            expected_test_options = ['path with spaces1', '--out', 'path with spaces2']
            expect(call(argv)).to eq(files: ['foo'], test_options: expected_test_options)
          end
        end
      end
    end
  end

  describe "#load_runner" do
    it "requires and loads default runner" do
      expect(subject).to receive(:require).with("parallel_tests/test/runner")
      expect(subject.send(:load_runner, "test")).to eq(ParallelTests::Test::Runner)
    end

    it "requires and loads rspec runner" do
      expect(subject).to receive(:require).with("parallel_tests/rspec/runner")
      expect(subject.send(:load_runner, "rspec")).to eq(ParallelTests::RSpec::Runner)
    end

    it "requires and loads runner with underscores" do
      expect(subject).to receive(:require).with("parallel_tests/my_test_runner/runner")
      expect(subject.send(:load_runner, "my_test_runner")).to eq(ParallelTests::MyTestRunner::Runner)
    end

    it "fails to load unfindable runner" do
      expect  do
        expect(subject.send(:load_runner, "foo")).to eq(ParallelTests::RSpec::Runner)
      end.to raise_error(LoadError)
    end
  end

  describe ".report_failure_rerun_command" do
    let(:single_failed_command) { [{ exit_status: 1, command: ['foo'], seed: nil, output: 'blah' }] }

    it "prints nothing if there are no failures" do
      expect($stdout).not_to receive(:puts)

      subject.send(
        :report_failure_rerun_commmand,
        [
          { exit_status: 0, command: 'foo', seed: nil, output: 'blah' }
        ],
        { verbose: true }
      )
    end

    def self.it_prints_nothing_about_rerun_commands(options)
      it 'prints nothing about rerun commands' do
        expect do
          subject.send(:report_failure_rerun_commmand, single_failed_command, options)
        end.to_not output(/Use the following command to run the group again/).to_stdout
      end
    end

    describe "failure" do
      before do
        subject.instance_variable_set(:@runner, ParallelTests::Test::Runner)
      end

      context 'without options' do
        it_prints_nothing_about_rerun_commands({})
      end

      context 'with verbose disabled' do
        it_prints_nothing_about_rerun_commands(verbose: false)
      end

      context "with verbose rerun command" do
        it "prints command if there is a failure" do
          expect do
            subject.send(:report_failure_rerun_commmand, single_failed_command, verbose_rerun_command: true)
          end.to output("\n\nTests have failed for a parallel_test group. Use the following command to run the group again:\n\nTEST_ENV_NUMBER= PARALLEL_TEST_GROUPS= foo\n").to_stdout
        end
      end

      context 'with verbose' do
        it "prints a message and the command if there is a failure" do
          expect do
            subject.send(:report_failure_rerun_commmand, single_failed_command, verbose: true)
          end.to output("\n\nTests have failed for a parallel_test group. Use the following command to run the group again:\n\nTEST_ENV_NUMBER= PARALLEL_TEST_GROUPS= foo\n").to_stdout
        end

        it "prints multiple commands if there are multiple failures" do
          expect do
            subject.send(
              :report_failure_rerun_commmand,
              [
                { exit_status: 1, command: ['foo'], seed: nil, output: 'blah' },
                { exit_status: 1, command: ['bar'], seed: nil, output: 'blah' },
                { exit_status: 1, command: ['baz'], seed: nil, output: 'blah' }
              ],
              { verbose: true }
            )
          end.to output(/\sfoo\n.+?\sbar\n.+?\sbaz/).to_stdout
        end

        it "only includes failures" do
          expect do
            subject.send(
              :report_failure_rerun_commmand,
              [
                { exit_status: 1, command: ['foo', '--color'], seed: nil, output: 'blah' },
                { exit_status: 0, command: ['bar'], seed: nil, output: 'blah' },
                { exit_status: 1, command: ['baz'], seed: nil, output: 'blah' }
              ],
              { verbose: true }
            )
          end.to output(/\sfoo --color\n.+?\sbaz/).to_stdout
        end

        it "prints the command with the seed added by the runner" do
          command = ['rspec', '--color', 'spec/foo_spec.rb']
          seed = 555

          expect(ParallelTests::Test::Runner).to receive(:command_with_seed).with(command, seed)
            .and_return(['my', 'seeded', 'command', 'result', '--seed', seed])
          single_failed_command[0].merge!(seed: seed, command: command)

          expect do
            subject.send(:report_failure_rerun_commmand, single_failed_command, verbose: true)
          end.to output(/my seeded command result --seed 555/).to_stdout
        end
      end
    end
  end

  describe "#final_fail_message" do
    before do
      subject.instance_variable_set(:@runner, ParallelTests::Test::Runner)
    end

    it 'returns a plain fail message if colors are nor supported' do
      expect(subject).to receive(:use_colors?).and_return(false)
      expect(subject.send(:final_fail_message)).to eq("Tests Failed")
    end

    it 'returns a colorized fail message if colors are supported' do
      expect(subject).to receive(:use_colors?).and_return(true)
      expect(subject.send(:final_fail_message)).to eq("\e[31mTests Failed\e[0m")
    end
  end

  describe "#run_tests_in_parallel" do
    context "specific groups to run" do
      let(:results) { { stdout: "", exit_status: 0 } }
      let(:common_options) do
        { files: ["test"], group_by: :filesize, first_is_1: false }
      end
      before do
        allow(subject).to receive(:puts)
        expect(subject).to receive(:load_runner).with("my_test_runner").and_return(ParallelTests::MyTestRunner::Runner)
        allow(ParallelTests::MyTestRunner::Runner).to receive(:test_file_name).and_return("test")
        expect(ParallelTests::MyTestRunner::Runner).to receive(:tests_in_groups).and_return(
          [
            ['aaa', 'bbb'],
            ['ccc', 'ddd'],
            ['eee', 'fff']
          ]
        )
        expect(subject).to receive(:report_results).and_return(nil)
      end

      it "calls run_tests once when one group specified" do
        expect(subject).to receive(:run_tests).once.and_return(results)
        subject.run(['test', '-n', '3', '--only-group', '1', '-t', 'my_test_runner'])
      end

      it "calls run_tests twice when two groups are specified" do
        expect(subject).to receive(:run_tests).twice.and_return(results)
        subject.run(['test', '-n', '3', '--only-group', '1,2', '-t', 'my_test_runner'])
      end

      it "run only one group specified" do
        options = common_options.merge(count: 3, only_group: [2])
        expect(subject).to receive(:run_tests).once.with(['ccc', 'ddd'], 0, 1, options).and_return(results)
        subject.run(['test', '-n', '3', '--only-group', '2', '-t', 'my_test_runner'])
      end

      it "run last group when passing a group that is not filled" do
        count = 3
        options = common_options.merge(count: count, only_group: [count])
        expect(subject).to receive(:run_tests).once.with(['eee', 'fff'], 0, 1, options).and_return(results)
        subject.run(['test', '-n', count.to_s, '--only-group', count.to_s, '-t', 'my_test_runner'])
      end

      it "run twice with multiple groups" do
        skip "fails on jruby" if RUBY_PLATFORM == "java"
        options = common_options.merge(count: 3, only_group: [2, 3])
        expect(subject).to receive(:run_tests).once.with(['ccc', 'ddd'], 0, 1, options).and_return(results)
        expect(subject).to receive(:run_tests).once.with(['eee', 'fff'], 1, 1, options).and_return(results)
        subject.run(['test', '-n', '3', '--only-group', '2,3', '-t', 'my_test_runner'])
      end
    end

    context 'when --allow-duplicates' do
      let(:results) { { stdout: "", exit_status: 0 } }
      let(:processes) { 2 }
      let(:common_options) do
        { files: ['test'], allow_duplicates: true, first_is_1: false }
      end
      before do
        allow(subject).to receive(:puts)
        expect(subject).to receive(:load_runner).with("my_test_runner").and_return(ParallelTests::MyTestRunner::Runner)
        allow(ParallelTests::MyTestRunner::Runner).to receive(:test_file_name).and_return("test")
        expect(subject).to receive(:report_results).and_return(nil)
      end

      before do
        expect(ParallelTests::MyTestRunner::Runner).to receive(:tests_in_groups).and_return(
          [
            ['foo'],
            ['foo'],
            ['bar']
          ]
        )
      end

      it "calls run_tests with --only-group" do
        options = common_options.merge(count: processes, only_group: [2, 3], group_by: :filesize)
        expect(subject).to receive(:run_tests).once.with(['foo'], 0, 1, options).and_return(results)
        expect(subject).to receive(:run_tests).once.with(['bar'], 1, 1, options).and_return(results)
        subject.run(['test', '-n', processes.to_s, '--allow-duplicates', '--only-group', '2,3', '-t', 'my_test_runner'])
      end

      it "calls run_tests with --first-is-1" do
        options = common_options.merge(count: processes, first_is_1: true)
        expect(subject).to receive(:run_tests).once.with(['foo'], 0, processes, options).and_return(results)
        expect(subject).to receive(:run_tests).once.with(['foo'], 1, processes, options).and_return(results)
        expect(subject).to receive(:run_tests).once.with(['bar'], 2, processes, options).and_return(results)
        subject.run(['test', '-n', processes.to_s, '--first-is-1', '--allow-duplicates', '-t', 'my_test_runner'])
      end
    end
  end

  describe "#display_duration" do
    def call(*args)
      subject.send(:detailed_duration, *args)
    end

    it "displays for durations near one minute" do
      expect(call(59)).to eq(nil)
      expect(call(60)).to eq(" (1:00)")
      expect(call(61)).to eq(" (1:01)")
    end

    it "displays for durations near one hour" do
      expect(call(3599)).to eq(" (59:59)")
      expect(call(3600)).to eq(" (1:00:00)")
      expect(call(3601)).to eq(" (1:00:01)")
    end

    it "displays the correct string for miscellaneous durations" do
      expect(call(9296)).to  eq(" (2:34:56)")
      expect(call(45296)).to eq(" (12:34:56)")
      expect(call(2756601)).to eq(" (765:43:21)") # hours into three digits?  Buy more CI hardware...
      expect(call(0)).to eq(nil)
    end
  end
end

module ParallelTests
  module MyTestRunner
    class Runner
    end
  end
end
