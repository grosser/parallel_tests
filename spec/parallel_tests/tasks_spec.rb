require 'spec_helper'
require 'parallel_tests/tasks'

describe ParallelTests::Tasks do
  describe ".parse_args" do
    it "should return the count" do
      args = {:count => 2}
      ParallelTests::Tasks.parse_args(args).should == [2, "", ""]
    end

    it "should default to the prefix" do
      args = {:count => "models"}
      ParallelTests::Tasks.parse_args(args).should == [nil, "models", ""]
    end

    it "should return the count and pattern" do
      args = {:count => 2, :pattern => "models"}
      ParallelTests::Tasks.parse_args(args).should == [2, "models", ""]
    end

    it "should return the count, pattern, and options" do
      args = {:count => 2, :pattern => "plain", :options => "-p default"}
      ParallelTests::Tasks.parse_args(args).should == [2, "plain", "-p default"]
    end

    it "should return the count, pattern, and options" do
      args = {
        :count => 2,
        :pattern => "plain",
        :options => "-p default --group-by steps",
      }
      ParallelTests::Tasks.parse_args(args).should == [2, "plain", "-p default --group-by steps"]
    end
  end

  describe ".rails_env" do
    around do |example|
      begin
        old = ENV["RAILS_ENV"]
        ENV.delete "RAILS_ENV"
        example.call
      ensure
        ENV["RAILS_ENV"] = old
      end
    end

    it "should be test when nothing was set" do
      ParallelTests::Tasks.rails_env.should == "test"
    end

    it "should be whatever was set" do
      ENV["RAILS_ENV"] = "foo"
      ParallelTests::Tasks.rails_env.should == "foo"
    end
  end

  describe ".run_in_parallel" do
    let(:full_path){ File.expand_path("../../../bin/parallel_test", __FILE__) }

    it "has the executable" do
      File.file?(full_path).should == true
      File.executable?(full_path).should == true
    end

    it "runs command in parallel" do
      ParallelTests::Tasks.should_receive(:system).with("#{full_path} --exec 'echo'").and_return true
      ParallelTests::Tasks.run_in_parallel("echo")
    end

    it "runs command with :count option" do
      ParallelTests::Tasks.should_receive(:system).with("#{full_path} --exec 'echo' -n 123").and_return true
      ParallelTests::Tasks.run_in_parallel("echo", :count => 123)
    end

    it "runs without -n with blank :count option" do
      ParallelTests::Tasks.should_receive(:system).with("#{full_path} --exec 'echo'").and_return true
      ParallelTests::Tasks.run_in_parallel("echo", :count => "")
    end

    it "runs command with :non_parallel option" do
      ParallelTests::Tasks.should_receive(:system).with("#{full_path} --exec 'echo' --non-parallel").and_return true
      ParallelTests::Tasks.run_in_parallel("echo", :non_parallel => true)
    end

    it "runs aborts if the command fails" do
      ParallelTests::Tasks.should_receive(:system).and_return false
      ParallelTests::Tasks.should_receive(:abort).and_return false
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
          pending "pipefail is not supported on your system"
        end
      end

      it "should hide offending lines" do
        call("echo 123", "123").should == ["", true]
      end

      it "should not hide other lines" do
        call("echo 124", "123").should == ["124\n", true]
      end

      it "should fail if command fails and the pattern matches" do
        call("echo 123 && test", "123").should == ["", false]
      end

      it "should fail if command fails and the pattern fails" do
        call("echo 124 && test", "123").should == ["124\n", false]
      end
    end

    context "without pipefail supported" do
      before do
        ParallelTests::Tasks.should_receive(:system).with('/bin/bash', '-c', 'set -o pipefail 2>/dev/null && test 1').and_return false
      end

      it "should not filter and succeed" do
        call("echo 123", "123").should == ["123\n", true]
      end

      it "should not filter and fail" do
        call("echo 123 && test", "123").should == ["123\n", false]
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
      foo.should == 2
    end

    it "should run pending migrations is app task is defined" do
      foo = 1
      Rake::Task.define_task("app:db:abort_if_pending_migrations") do
        foo = 2
      end
      ParallelTests::Tasks.check_for_pending_migrations
      foo.should == 2
    end

    it "should not execute the task twice" do
      foo = 1
      Rake::Task.define_task("db:abort_if_pending_migrations") do
        foo += 1
      end
      ParallelTests::Tasks.check_for_pending_migrations
      ParallelTests::Tasks.check_for_pending_migrations
      foo.should == 2
    end
  end
end
