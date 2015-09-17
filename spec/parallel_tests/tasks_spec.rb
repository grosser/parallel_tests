require 'spec_helper'
require 'parallel_tests/tasks'

describe ParallelTests::Tasks do
  describe ".parse_args" do
    it "should return the count" do
      args = {:count => 2}
      expect(ParallelTests::Tasks.parse_args(args)).to eq([2, "", ""])
    end

    it "should default to the prefix" do
      args = {:count => "models"}
      expect(ParallelTests::Tasks.parse_args(args)).to eq([nil, "models", ""])
    end

    it "should return the count and pattern" do
      args = {:count => 2, :pattern => "models"}
      expect(ParallelTests::Tasks.parse_args(args)).to eq([2, "models", ""])
    end

    it "should return the count, pattern, and options" do
      args = {:count => 2, :pattern => "plain", :options => "-p default"}
      expect(ParallelTests::Tasks.parse_args(args)).to eq([2, "plain", "-p default"])
    end

    it "should return the count, pattern, and options" do
      args = {
        :count => 2,
        :pattern => "plain",
        :options => "-p default --group-by steps",
      }
      expect(ParallelTests::Tasks.parse_args(args)).to eq([2, "plain", "-p default --group-by steps"])
    end

    it "should use count, pattern, and options in calling the cli" do
      expect_any_instance_of(Object).to receive(:system)
        .with(/parallel_test test --type test -n 5 --pattern 'foo' -p default --group-by steps/)
        .and_return(true)

      Rake.application['parallel:test'].invoke(5,"foo","-p default --group-by steps")
    end
  end

  describe ".rails_env" do
    it "should be test when nothing was set" do
      expect(ParallelTests::Tasks.rails_env).to eq("test")
    end

    it "should be whatever was set" do
      ENV["RAILS_ENV"] = "foo"
      expect(ParallelTests::Tasks.rails_env).to eq("foo")
    end
  end

  describe ".run_in_parallel" do
    let(:full_path){ File.expand_path("../../../bin/parallel_test", __FILE__) }

    it "has the executable" do
      expect(File.file?(full_path)).to eq(true)
      expect(File.executable?(full_path)).to eq(true)
    end

    it "runs command in parallel" do
      expect(ParallelTests::Tasks).to receive(:system).with("#{full_path} --exec 'echo'").and_return true
      ParallelTests::Tasks.run_in_parallel("echo")
    end

    it "runs command with :count option" do
      expect(ParallelTests::Tasks).to receive(:system).with("#{full_path} --exec 'echo' -n 123").and_return true
      ParallelTests::Tasks.run_in_parallel("echo", :count => 123)
    end

    it "runs without -n with blank :count option" do
      expect(ParallelTests::Tasks).to receive(:system).with("#{full_path} --exec 'echo'").and_return true
      ParallelTests::Tasks.run_in_parallel("echo", :count => "")
    end

    it "runs command with :non_parallel option" do
      expect(ParallelTests::Tasks).to receive(:system).with("#{full_path} --exec 'echo' --non-parallel").and_return true
      ParallelTests::Tasks.run_in_parallel("echo", :non_parallel => true)
    end

    it "runs aborts if the command fails" do
      expect(ParallelTests::Tasks).to receive(:system).and_return false
      expect(ParallelTests::Tasks).to receive(:abort).and_return false
      ParallelTests::Tasks.run_in_parallel("echo")
    end
  end

  describe ".suppress_output" do
    def call(command, grep)
      # Explictly run as a parameter to /bin/sh to simulate how
      # the command will be run by parallel_test --exec
      # This also tests shell escaping of single quotes
      result = `/bin/sh -c '#{ParallelTests::Tasks.suppress_output(command, grep)}'`
      [result, $?.success?]
    end

    context "with pipefail supported" do
      before :all do
        if not system("/bin/bash", "-c", "set -o pipefail 2>/dev/null && test 1")
          skip "pipefail is not supported on your system"
        end
      end

      it "should hide offending lines" do
        expect(call("echo 123", "123")).to eq(["", true])
      end

      it "should not hide other lines" do
        expect(call("echo 124", "123")).to eq(["124\n", true])
      end

      it "should fail if command fails and the pattern matches" do
        expect(call("echo 123 && test", "123")).to eq(["", false])
      end

      it "should fail if command fails and the pattern fails" do
        expect(call("echo 124 && test", "123")).to eq(["124\n", false])
      end
    end

    context "without pipefail supported" do
      before do
        expect(ParallelTests::Tasks).to receive(:system).with('/bin/bash', '-c', 'set -o pipefail 2>/dev/null && test 1').and_return false
      end

      it "should not filter and succeed" do
        expect(call("echo 123", "123")).to eq(["123\n", true])
      end

      it "should not filter and fail" do
        expect(call("echo 123 && test", "123")).to eq(["123\n", false])
      end
    end
  end

  describe ".check_for_pending_migrations" do
    after do
      Rake.application.instance_variable_get('@tasks').delete("db:abort_if_pending_migrations")
      Rake.application.instance_variable_get('@tasks').delete("app:db:abort_if_pending_migrations")
    end

    it "should do nothing if pending migrations is no defined" do
      ParallelTests::Tasks.check_for_pending_migrations
    end

    it "should run pending migrations is task is defined" do
      foo = 1
      Rake::Task.define_task("db:abort_if_pending_migrations") do
        foo = 2
      end
      ParallelTests::Tasks.check_for_pending_migrations
      expect(foo).to eq(2)
    end

    it "should run pending migrations is app task is defined" do
      foo = 1
      Rake::Task.define_task("app:db:abort_if_pending_migrations") do
        foo = 2
      end
      ParallelTests::Tasks.check_for_pending_migrations
      expect(foo).to eq(2)
    end

    it "should not execute the task twice" do
      foo = 1
      Rake::Task.define_task("db:abort_if_pending_migrations") do
        foo += 1
      end
      ParallelTests::Tasks.check_for_pending_migrations
      ParallelTests::Tasks.check_for_pending_migrations
      expect(foo).to eq(2)
    end
  end
end
