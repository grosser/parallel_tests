require 'spec_helper'

describe ParallelCucumber do
  test_tests_in_groups(ParallelCucumber, 'features', ".feature")

  describe :run_tests do
    before do
      ParallelCucumber.stub!(:bundler_enabled?).and_return false
      File.stub!(:file?).with('.bundle/environment.rb').and_return false
      File.stub!(:file?).with('script/cucumber').and_return true
    end

    it "uses TEST_ENV_NUMBER=blank when called for process 0" do
      ParallelCucumber.should_receive(:open).with{|x,y| x=~/TEST_ENV_NUMBER= /}.and_return mocked_process
      ParallelCucumber.run_tests(['xxx'],0,{})
    end

    it "uses TEST_ENV_NUMBER=2 when called for process 1" do
      ParallelCucumber.should_receive(:open).with{|x,y| x=~/TEST_ENV_NUMBER=2/}.and_return mocked_process
      ParallelCucumber.run_tests(['xxx'],1,{})
    end

    it "returns the output" do
      io = open('spec/spec_helper.rb')
      ParallelCucumber.stub!(:print)
      ParallelCucumber.should_receive(:open).and_return io
      ParallelCucumber.run_tests(['xxx'],1,{})[:stdout].should =~ /\$LOAD_PATH << File/
    end

    it "runs bundle exec cucumber when on bundler 0.9" do
      ParallelCucumber.stub!(:bundler_enabled?).and_return true
      ParallelCucumber.should_receive(:open).with{|x,y| x =~ %r{bundle exec cucumber}}.and_return mocked_process
      ParallelCucumber.run_tests(['xxx'],1,{})
    end

    it "runs script/cucumber when script/cucumber is found" do
      ParallelCucumber.should_receive(:open).with{|x,y| x =~ %r{script/cucumber}}.and_return mocked_process
      ParallelCucumber.run_tests(['xxx'],1,{})
    end

    it "runs cucumber by default" do
      File.stub!(:file?).with('script/cucumber').and_return false
      ParallelCucumber.should_receive(:open).with{|x,y| x !~ %r{(script/cucumber)|(bundle exec cucumber)}}.and_return mocked_process
      ParallelCucumber.run_tests(['xxx'],1,{})
    end

    it "uses options passed in" do
      ParallelCucumber.should_receive(:open).with{|x,y| x =~ %r{script/cucumber .* -p default}}.and_return mocked_process
      ParallelCucumber.run_tests(['xxx'],1,:test_options => '-p default')
    end
  end

  describe :runtime_log do
    it "should use the PARALLEL_TEST_RUNTIME_LOG env var if set" do
      ENV['PARALLEL_TEST_RUNTIME_LOG'] = "tmp/my-runtime.log"
      ParallelCucumber.runtime_log.should == "tmp/my-runtime.log"
      ENV['PARALLEL_TEST_RUNTIME_LOG'] = nil
    end

    it "should use the runtime_log option over PARALLEL_TEST_RUNTIME_LOG env var if set" do
      ENV['PARALLEL_TEST_RUNTIME_LOG'] = "tmp/my-runtime.log"
      opts = { :runtime_log => "tmp/my-other-runtime.log" }
      ParallelCucumber.runtime_log(opts).should == "tmp/my-other-runtime.log"
      ENV['PARALLEL_TEST_RUNTIME_LOG'] = nil
    end

    it "should use the static parallel cucumber log by default" do
      ParallelCucumber.runtime_log.should == 'tmp/parallel_runtime_cucumber.log'
    end
  end

  describe :sort_datafile do
    it "should use the PARALLEL_TEST_SORT_DATAFILE env var if set" do
      ENV['PARALLEL_TEST_SORT_DATAFILE'] = "tmp/my-sort.datafile"
      ParallelCucumber.sort_datafile.should == "tmp/my-sort.datafile"
      ENV['PARALLEL_TEST_SORT_DATAFILE'] = nil
    end

    it "should use the sort_datafile option over PARALLEL_TEST_SORT_DATAFILE env var if set" do
      ENV['PARALLEL_TEST_SORT_DATAFILE'] = "tmp/my-sort.datafile"
      opts = { :sort_datafile => "tmp/my-other-sort.datafile" }
      ParallelCucumber.sort_datafile(opts).should == "tmp/my-other-sort.datafile"
      ENV['PARALLEL_TEST_SORT_DATAFILE'] = nil
    end

    it "should use the static parallel cucumber log by default" do
      ParallelCucumber.sort_datafile.should == 'tmp/parallel_runtime_cucumber.log'
    end
  end

  describe :find_results do
    it "finds multiple results in test output" do
      output = <<EOF
And I should not see "/en/"                                       # features/step_definitions/webrat_steps.rb:87

7 scenarios (3 failed, 4 passed)
33 steps (3 failed, 2 skipped, 28 passed)
/apps/rs/features/signup.feature:2
    Given I am on "/"                                           # features/step_definitions/common_steps.rb:12
    When I click "register"                                     # features/step_definitions/common_steps.rb:6
    And I should have "2" emails                                # features/step_definitions/user_steps.rb:25

4 scenarios (4 passed)
40 steps (40 passed)

EOF
      ParallelCucumber.find_results(output).should == ["7 scenarios (3 failed, 4 passed)", "33 steps (3 failed, 2 skipped, 28 passed)", "4 scenarios (4 passed)", "40 steps (40 passed)"]
    end
  end
end
