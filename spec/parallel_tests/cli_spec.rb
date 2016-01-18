require "spec_helper"
require "parallel_tests/cli"
require "parallel_tests/rspec/runner"

describe ParallelTests::CLI do
  subject { ParallelTests::CLI.new }

  describe "#parse_options" do
    let(:defaults){ {:files => ["test"]} }

    def call(*args)
      subject.send(:parse_options!, *args)
    end

    it "fails without file" do
      expect(subject).to receive(:abort).with("Pass files or folders to run")
      call(["-n3"])
    end

    it "parses execute" do
      expect(call(["--exec", "echo"])).to eq(execute: "echo")
    end

    it "parses regular count" do
      expect(call(["test", "-n3"])).to eq(defaults.merge(:count => 3))
    end

    it "parses count 0 as non-parallel" do
      expect(call(["test", "-n0"])).to eq(defaults.merge(:non_parallel => true))
    end

    it "parses non-parallel as non-parallel" do
      expect(call(["test", "--non-parallel"])).to eq(defaults.merge(:non_parallel => true))
    end

    it "finds the correct type when multiple are given" do
      call(["test", "--type", "test", "-t", "rspec"])
      expect(subject.instance_variable_get(:@runner)).to eq(ParallelTests::RSpec::Runner)
    end

    it "parses nice as nice" do
      expect(call(["test", "--nice"])).to eq(defaults.merge(:nice => true))
    end

    it "parses --verbose" do
      expect(call(["test", "--verbose"])).to eq(defaults.merge(:verbose => true))
    end

    it "parses --suffix" do
      expect(call(["test", "--suffix", "_(test|spec).rb$"])).to eq(defaults.merge(:suffix => /_(test|spec).rb$/))
    end

    it "parses --use-test-env-number-for-first-process" do
      expect(call(["test", "--use-test-env-number-for-first-process"])).
        to eq(defaults.merge(:use_test_env_number_for_first_process => true))
    end

    context "parse only-group" do
      it "group_by should be set to filesize" do
        expect(call(["test", "--only-group", '1'])).to eq(defaults.merge(only_group: [1], group_by: :filesize))
      end

      it "allows runtime" do
        expect(call(["test", "--only-group", '1', '--group-by', 'runtime'])).to eq(defaults.merge(only_group: [1], group_by: :runtime))
      end

      it "raise error when group_by isn't filesize" do
        expect{
          call(["test", "--only-group", '1', '--group-by', 'steps'])
        }.to raise_error(RuntimeError)
      end

      it "with multiple groups" do
        expect(call(["test", "--only-group", '4,5'])).to eq(defaults.merge(only_group: [4,5], group_by: :filesize))
      end

      it "with a single group" do
        expect(call(["test", "--only-group", '4'])).to eq(defaults.merge(:only_group => [4], group_by: :filesize))
      end
    end

    context "when the -- option separator is used" do
      it "interprets arguments as files/directories" do
        expect(call(%w(-- test))).to eq( files: %w(test))
        expect(call(%w(-- test test2))).to eq( files: %w(test test2))
        expect(call(%w(-- --foo test))).to eq( files: %w(--foo test))
        expect(call(%w(-- test --foo test2))).to eq( files: %w(test --foo test2))

      end

      it "corectly handles arguments with spaces" do
        expect(call(['--', 'file name with space'])).to eq( files: ['file name with space'])
      end

      context "when the -o options has also been given" do
        it "merges the options together" do
          expect(call(%w(-o '-f' -- test --foo test2))).to eq( files: %w(test --foo test2), test_options: "'-f'")
        end
      end

      context "when a second -- option separator is used" do
        it "interprets the first set as test_options" do
          expect(call(%w(-- -r foo -- test))).to eq( files: %w(test), test_options: '-r foo')
          expect(call(%w(-- -r foo -- test test2))).to eq( files: %w(test test2), test_options: '-r foo')
          expect(call(%w(-- -r foo -o out.log -- test test2))).to eq( files: %w(test test2), test_options: '-r foo -o out.log')
        end

        context "when existing test_options have previously been given" do
          it "appends the new options" do
            expect(call(%w(-o '-f' -- -r foo.rb -- test))).to eq( files: %w(test), test_options: "'-f' -r foo.rb")
          end
          it "corectly handles argument values with spaces" do
            argv = ["-o 'path with spaces1'", '--', '--out', 'path with spaces2', '--', 'foo']
            expected_test_options = "'path with spaces1' --out path\\ with\\ spaces2"
            expect(call(argv)).to eq( files: %w(foo), test_options: expected_test_options)
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
      expect{
        expect(subject.send(:load_runner, "foo")).to eq(ParallelTests::RSpec::Runner)
      }.to raise_error(LoadError)
    end
  end

  describe ".report_failure_rerun_commmand" do
    it "prints nothing if there are no failures" do
      expect($stdout).not_to receive(:puts)

      subject.send(:report_failure_rerun_commmand,
        [
          {exit_status: 0, command: 'foo', seed: nil, output: 'blah'}
        ],
        {verbose: true}
      )
    end

    shared_examples :not_verbose_rerun do |options|
      it 'prints nothing about rerun commands' do
          expect {
            subject.send(:report_failure_rerun_commmand,
              [
                {exit_status: 1, command: 'foo', seed: nil, output: 'blah'}
              ],
              options
            )
          }.to_not output(/Use the following command to run the group again/).to_stdout
      end
    end

    describe "failure" do
      context 'with empty options hash' do
        include_examples :not_verbose_rerun, {}
      end

      context 'with option !verbose' do
        include_examples :not_verbose_rerun, {verbose: false}
      end

      context 'with option verbose' do
        it "prints a message and the command if there is a failure" do
          expect {
            subject.send(:report_failure_rerun_commmand,
              [
                {exit_status: 1, command: 'foo', seed: nil, output: 'blah'}
              ],
              {verbose: true}
            )
          }.to output("\n\nTests have failed for a parallel_test group. Use the following command to run the group again:\n\nfoo\n").to_stdout
        end

        it "prints multiple commands if there are multiple failures" do
          expect {
            subject.send(:report_failure_rerun_commmand,
              [
                {exit_status: 1, command: 'foo', seed: nil, output: 'blah'},
                {exit_status: 1, command: 'bar', seed: nil, output: 'blah'},
                {exit_status: 1, command: 'baz', seed: nil, output: 'blah'},
              ],
              {verbose: true}
            )
          }.to output(/foo\nbar\nbaz/).to_stdout
        end

        it "only includes failures" do
          expect { 
            subject.send(:report_failure_rerun_commmand,
              [
                {exit_status: 1, command: 'foo --color', seed: nil, output: 'blah'},
                {exit_status: 0, command: 'bar', seed: nil, output: 'blah'},
                {exit_status: 1, command: 'baz', seed: nil, output: 'blah'},
              ],
              {verbose: true}
            )
          }.to output(/foo --color\nbaz/).to_stdout
        end

        it "prints the command with the seed added by the runner" do
          command = 'rspec --color spec/foo_spec.rb'
          seed = 555

          subject.instance_variable_set(:@runner, ParallelTests::Test::Runner)
          expect(ParallelTests::Test::Runner).to receive(:command_with_seed).with(command, seed).
            and_return("my seeded command result --seed #{seed}")
          expect { 
            subject.send(:report_failure_rerun_commmand,
              [
                {exit_status: 1, command: command, seed: 555, output: 'blah'},
              ],
              {verbose: true}
            )
          }.to output(/my seeded command result --seed 555/).to_stdout
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
      let(:results){ {:stdout => "", :exit_status => 0} }
      let(:common_options) {
        { files: ["test"], group_by: :filesize, use_test_env_number_for_first_process: nil }
      }
      before do
        allow(subject).to receive(:puts)
        expect(subject).to receive(:load_runner).with("my_test_runner").and_return(ParallelTests::MyTestRunner::Runner)
        allow(ParallelTests::MyTestRunner::Runner).to receive(:test_file_name).and_return("test")
        expect(ParallelTests::MyTestRunner::Runner).to receive(:tests_in_groups).and_return([
          ['aaa','bbb'],
          ['ccc', 'ddd'],
          ['eee', 'fff']
        ])
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
        options = common_options.merge(count: 3, only_group: [2,3])
        expect(subject).to receive(:run_tests).once.ordered.with(['ccc', 'ddd'], 0, 1, options).and_return(results)
        expect(subject).to receive(:run_tests).once.ordered.with(['eee', 'fff'], 1, 1, options).and_return(results)
        subject.run(['test', '-n', '3', '--only-group', '2,3', '-t', 'my_test_runner'])
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
