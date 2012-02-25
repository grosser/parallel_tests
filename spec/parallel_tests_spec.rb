require "spec_helper"

describe ParallelTests do
  describe :parse_rake_args do
    it "should return the count" do
      args = {:count => 2}
      ParallelTests.parse_rake_args(args).should == [2, '', ""]
    end

    it "should default to the prefix" do
      args = {:count => "models"}
      ParallelTests.parse_rake_args(args).should == [nil, "models", ""]
    end

    it "should return the count and pattern" do
      args = {:count => 2, :pattern => "models"}
      ParallelTests.parse_rake_args(args).should == [2, "models", ""]
    end

    it "should return the count, pattern, and options" do
      args = {:count => 2, :pattern => "plain", :options => "-p default" }
      ParallelTests.parse_rake_args(args).should == [2, "plain", "-p default"]
    end
  end

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

  describe :bundler_enabled? do
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

  it "has a version" do
    ParallelTests::VERSION.should =~ /^\d+\.\d+\.\d+/
  end
end
