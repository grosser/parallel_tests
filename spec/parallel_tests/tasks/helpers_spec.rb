# frozen_string_literal: true
require 'spec_helper'
require 'parallel_tests/tasks/helpers'

describe ParallelTests::Tasks::Helpers do
  describe ".parse_args" do
    it "should return the count" do
      args = { count: 2 }
      expect(described_class.parse_args(args)).to eq([2, nil, nil, nil])
    end

    it "should default to the prefix" do
      args = { count: "models" }
      expect(described_class.parse_args(args)).to eq([nil, "models", nil, nil])
    end

    it "should return the count and pattern" do
      args = { count: 2, pattern: "models" }
      expect(described_class.parse_args(args)).to eq([2, "models", nil, nil])
    end

    it "should return the count, pattern, and options" do
      args = { count: 2, pattern: "plain", options: "-p default" }
      expect(described_class.parse_args(args)).to eq([2, "plain", "-p default", nil])
    end

    it "should return the count, pattern, and options" do
      args = { count: 2, pattern: "plain", options: "-p default --group-by steps" }
      expect(described_class.parse_args(args)).to eq([2, "plain", "-p default --group-by steps", nil])
    end

    it "should return the count, pattern, test options, and pass-through options" do
      args = {
        count: 2, pattern: "plain", options: "-p default --group-by steps",
        pass_through: "--runtime-log /path/to/log"
      }
      expect(described_class.parse_args(args)).to eq(
        [2, "plain", "-p default --group-by steps",
         "--runtime-log /path/to/log"]
      )
    end
  end

  describe ".rails_env" do
    it "should be test" do
      expect(described_class.rails_env).to eq("test")
    end

    it "should disregard whatever was set" do
      ENV["RAILS_ENV"] = "foo"
      expect(described_class.rails_env).to eq("test")
    end
  end

  describe ".run_in_parallel" do
    let(:full_path) { File.expand_path('../../../bin/parallel_test', __dir__) }

    it "has the executable" do
      expect(File.file?(full_path)).to eq(true)
      expect(File.executable?(full_path)).to eq(true) unless Gem.win_platform?
    end

    it "runs command in parallel" do
      expect(described_class).to receive(:system).
        with(*ParallelTests.with_ruby_binary(full_path), '--exec', 'echo').
        and_return true
      described_class.run_in_parallel(["echo"])
    end

    it "runs command with :count option" do
      expect(described_class).to receive(:system).
        with(*ParallelTests.with_ruby_binary(full_path), '--exec', 'echo', '-n', 123).
        and_return true
      described_class.run_in_parallel(["echo"], count: 123)
    end

    it "runs without -n with blank :count option" do
      expect(described_class).to receive(:system).
        with(*ParallelTests.with_ruby_binary(full_path), '--exec', 'echo').
        and_return true
      described_class.run_in_parallel(["echo"], count: "")
    end

    it "runs command with :non_parallel option" do
      expect(described_class).to receive(:system).
        with(*ParallelTests.with_ruby_binary(full_path), '--exec', 'echo', '--non-parallel').
        and_return true
      described_class.run_in_parallel(["echo"], non_parallel: true)
    end

    it "runs aborts if the command fails" do
      expect(described_class).to receive(:system).and_return false
      expect(described_class).to receive(:abort).and_return false
      described_class.run_in_parallel(["echo"])
    end
  end

  describe ".suppress_output", unless: Gem.win_platform? do
    def call(command, grep)
      # Explicitly run as a parameter to /bin/bash to simulate how
      # the command will be run by parallel_test --exec
      # This also tests shell escaping of single quotes
      shell_command = [
        '/bin/bash',
        '-c',
        Shellwords.shelljoin(described_class.suppress_output(command, grep))
      ]
      result = IO.popen(shell_command, &:read)
      [result, $?.success?]
    end

    context "with pipefail supported" do
      before :all do
        unless system("/bin/bash", "-c", "set -o pipefail 2>/dev/null")
          skip "pipefail is not supported on your system"
        end
      end

      it "should hide offending lines" do
        expect(call(["echo", "123"], "123")).to eq(["", true])
      end

      it "should not hide other lines" do
        expect(call(["echo", "124"], "123")).to eq(["124\n", true])
      end

      it "should fail if command fails and the pattern matches" do
        expect(call(['/bin/bash', '-c', 'echo 123 && false'], "123")).to eq(["", false])
      end

      it "should fail if command fails and the pattern fails" do
        expect(call(['/bin/bash', '-c', 'echo 124 && false'], "123")).to eq(["124\n", false])
      end
    end

    context "without pipefail supported" do
      before do
        expect(described_class).to receive(:system).with(
          '/bin/bash', '-c',
          'set -o pipefail 2>/dev/null'
        ).and_return false
      end

      it "should not filter and succeed" do
        expect(call(["echo", "123"], "123")).to eq(["123\n", true])
      end

      it "should not filter and fail" do
        expect(call(['/bin/bash', '-c', 'echo 123 && false'], "123")).to eq(["123\n", false])
      end
    end
  end

  describe ".suppress_schema_load_output" do
    before do
      allow(ParallelTests::Tasks::Helpers).to receive(:suppress_output)
    end

    it 'should call suppress output with command' do
      described_class.suppress_schema_load_output('command')
      expect(ParallelTests::Tasks::Helpers).to have_received(:suppress_output).
        with('command', "^   ->\\|^-- ")
    end
  end

  describe ".check_for_pending_migrations" do
    after do
      Rake.application.instance_variable_get('@tasks').delete("db:abort_if_pending_migrations")
      Rake.application.instance_variable_get('@tasks').delete("app:db:abort_if_pending_migrations")
    end

    it "should do nothing if pending migrations is no defined" do
      described_class.check_for_pending_migrations
    end

    it "should run pending migrations is task is defined" do
      foo = 1
      Rake::Task.define_task("db:abort_if_pending_migrations") do
        foo = 2
      end
      described_class.check_for_pending_migrations
      expect(foo).to eq(2)
    end

    it "should run pending migrations is app task is defined" do
      foo = 1
      Rake::Task.define_task("app:db:abort_if_pending_migrations") do
        foo = 2
      end
      described_class.check_for_pending_migrations
      expect(foo).to eq(2)
    end

    it "should not execute the task twice" do
      foo = 1
      Rake::Task.define_task("db:abort_if_pending_migrations") do
        foo += 1
      end
      described_class.check_for_pending_migrations
      described_class.check_for_pending_migrations
      expect(foo).to eq(2)
    end
  end

  describe ".purge_before_load" do
    context 'ActiveRecord < 4.2.0' do
      before do
        stub_const('ActiveRecord', double(version: Gem::Version.new('3.2.1')))
      end

      it "should return nil for ActiveRecord < 4.2.0" do
        expect(described_class.purge_before_load).to eq nil
      end
    end

    context 'ActiveRecord > 4.2.0' do
      before do
        stub_const('ActiveRecord', double(version: Gem::Version.new('4.2.8')))
      end

      it "should return db:purge when defined" do
        allow(Rake::Task).to receive(:task_defined?).with('db:purge') { true }

        expect(described_class.purge_before_load).to eq 'db:purge'
      end

      it "should return app:db:purge when db:purge is not defined" do
        allow(Rake::Task).to receive(:task_defined?).with('db:purge') { false }

        expect(described_class.purge_before_load).to eq 'app:db:purge'
      end
    end
  end

  describe ".build_run_command" do
    it "builds simple command" do
      command = described_class.build_run_command("test", {})
      command.shift 2 if command.include?("--") # windows prefixes ruby executable
      expect(command).to eq [
        "#{Dir.pwd}/bin/parallel_test", "test", "--type", "test"
      ]
    end

    it "fails on unknown" do
      expect { described_class.build_run_command("foo", {}) }.to raise_error(KeyError)
    end

    it "builds with all arguments" do
      command = described_class.build_run_command(
        "test",
        count: 1, pattern: "foo", options: "bar", pass_through: "baz baz"
      )
      command.shift 2 if command.include?("--") # windows prefixes ruby executable
      expect(command).to eq [
        "#{Dir.pwd}/bin/parallel_test", "test", "--type", "test",
        "-n", "1", "--pattern", "foo", "--test-options", "bar", "baz", "baz"
      ]
    end
  end
end
