require "spec_helper"

describe ParallelTests do
  describe ".determine_number_of_processes" do
    before do
      allow(Parallel).to receive(:processor_count).and_return 20
    end

    def call(count)
      ParallelTests.determine_number_of_processes(count)
    end

    it "uses the given count if set" do
      expect(call('5')).to eq(5)
    end

    it "uses the processor count from Parallel" do
      expect(call(nil)).to eq(20)
    end

    it "uses the processor count from ENV before Parallel" do
      ENV['PARALLEL_TEST_PROCESSORS'] = '22'
      expect(call(nil)).to eq(22)
    end

    it "does not use blank count" do
      expect(call('   ')).to eq(20)
    end

    it "does not use blank env" do
      ENV['PARALLEL_TEST_PROCESSORS'] = '   '
      expect(call(nil)).to eq(20)
    end
  end

  describe ".bundler_enabled?" do
    before do
      allow(Object).to receive(:const_defined?).with(:Bundler).and_return false
    end

    it "is false" do
      use_temporary_directory do
        expect(ParallelTests.send(:bundler_enabled?)).to eq(false)
      end
    end

    it "is true when there is a constant called Bundler" do
      use_temporary_directory do
        allow(Object).to receive(:const_defined?).with(:Bundler).and_return true
        expect(ParallelTests.send(:bundler_enabled?)).to eq(true)
      end
    end

    it "is true when there is a Gemfile" do
      use_temporary_directory do
        FileUtils.touch("Gemfile")
        expect(ParallelTests.send(:bundler_enabled?)).to eq(true)
      end
    end

    it "is true when there is a Gemfile in the parent directory" do
      use_temporary_directory do
        FileUtils.mkdir "nested"
        Dir.chdir "nested" do
          FileUtils.touch(File.join("..", "Gemfile"))
          expect(ParallelTests.send(:bundler_enabled?)).to eq(true)
        end
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
      expect(ParallelTests).not_to receive(:sleep)
      ParallelTests.wait_for_other_processes_to_finish
    end

    it "stops if only itself is running" do
      ENV["TEST_ENV_NUMBER"] = "2"
      expect(ParallelTests).not_to receive(:sleep)
      with_running_processes(1) do
        ParallelTests.wait_for_other_processes_to_finish
      end
    end

    it "waits for other processes to finish" do
      skip if RUBY_PLATFORM == "java"
      ENV["TEST_ENV_NUMBER"] = "2"
      counter = 0
      allow(ParallelTests).to receive(:sleep) do
        sleep 0.1;
        counter += 1
      end

      with_running_processes(2, 0.6) do
        ParallelTests.wait_for_other_processes_to_finish
      end
      expect(counter).to be >= 2
    end
  end

  describe ".number_of_running_processes" do
    it "is 0 for nothing" do
      expect(ParallelTests.number_of_running_processes).to eq(0)
    end

    it "is 2 when 2 are running" do
      wait = 0.2
      2.times { Thread.new { `TEST_ENV_NUMBER=1; sleep #{wait}` } }
      sleep wait / 2
      expect(ParallelTests.number_of_running_processes).to eq(2)
      sleep wait
    end
  end

  describe ".first_process?" do
    it "is first if no env is set" do
      expect(ParallelTests.first_process?).to eq(true)
    end

    it "is first if env is set to blank" do
      ENV["TEST_ENV_NUMBER"] = ""
      expect(ParallelTests.first_process?).to eq(true)
    end

    it "is not first if env is set to something" do
      ENV["TEST_ENV_NUMBER"] = "2"
      expect(ParallelTests.first_process?).to eq(false)
    end
  end

  it "has a version" do
    expect(ParallelTests::VERSION).to match(/^\d+\.\d+\.\d+/)
  end
end
