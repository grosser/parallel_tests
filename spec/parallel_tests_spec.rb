require "spec_helper"

describe ParallelTests do
  describe ".determine_number_of_processes" do
    before do
      ENV.delete('PARALLEL_TEST_PROCESSORS')
      Parallel.stub(:processor_count).and_return 20
    end

    def call(count)
      ParallelTests.determine_number_of_processes(count)
    end

    it "uses the given count if set" do
      call('5').should == 5
    end

    it "uses the processor count from Parallel" do
      call(nil).should == 20
    end

    it "uses the processor count from ENV before Parallel" do
      ENV['PARALLEL_TEST_PROCESSORS'] = '22'
      call(nil).should == 22
    end

    it "does not use blank count" do
      call('   ').should == 20
    end

    it "does not use blank env" do
      ENV['PARALLEL_TEST_PROCESSORS'] = '   '
      call(nil).should == 20
    end
  end

  describe ".bundler_enabled?" do
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

  describe ".wait_for_other_processes_to_finish" do
    def with_running_processes(count, wait=0.2)
      count.times { Thread.new{ `TEST_ENV_NUMBER=1; sleep #{wait}` } }
      sleep 0.1
      yield
    ensure
      sleep wait # make sure the threads have finished
    end

    it "does not wait if not run in parallel" do
      ParallelTests.should_not_receive(:sleep)
      ParallelTests.wait_for_other_processes_to_finish
    end

    it "stops if only itself is running" do
      ENV["TEST_ENV_NUMBER"] = "2"
      ParallelTests.should_not_receive(:sleep)
      with_running_processes(1) do
          ParallelTests.wait_for_other_processes_to_finish
        end
    end

    it "waits for other processes to finish" do
      pending if RUBY_ENGINE == "jruby"
      ENV["TEST_ENV_NUMBER"] = "2"
      counter = 0
      ParallelTests.stub(:sleep).with{ sleep 0.1; counter += 1 }
      with_running_processes(2, 0.4) do
        ParallelTests.wait_for_other_processes_to_finish
      end
      counter.should == 3
    end
  end

  describe ".number_of_running_processes" do
    it "is 0 for nothing" do
      ParallelTests.number_of_running_processes.should == 0
    end

    it "is 2 when 2 are running" do
      wait = 0.2
      2.times do
        Thread.new do
          if RUBY_ENGINE == "jruby"
            Thread.current[:running_parallel_test] = true
            sleep wait
          else
            `TEST_ENV_NUMBER=1; sleep #{wait}`
          end
        end
      end
      sleep wait / 2
      ParallelTests.number_of_running_processes.should == 2
      sleep wait
    end
  end

  describe ".first_process?" do
    it "is first if no env is set" do
      ParallelTests.first_process?.should == true
    end

    it "is first if env is set to blank" do
      ENV["TEST_ENV_NUMBER"] = ""
      ParallelTests.first_process?.should == true
    end

    it "is not first if env is set to something" do
      ENV["TEST_ENV_NUMBER"] = "2"
      ParallelTests.first_process?.should == false
    end
  end

  it "has a version" do
    ParallelTests::VERSION.should =~ /^\d+\.\d+\.\d+/
  end
end
