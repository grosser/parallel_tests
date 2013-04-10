require "spec_helper"
require "parallel_tests/cucumber/runner"

describe ParallelTests::Cucumber do
  test_tests_in_groups(ParallelTests::Cucumber::Runner, 'features', ".feature")

  describe :run_tests do
    before do
      ParallelTests.stub!(:bundler_enabled?).and_return false
      File.stub!(:file?).with('.bundle/environment.rb').and_return false
      File.stub!(:file?).with('script/cucumber').and_return true
    end

    def call(*args)
      ParallelTests::Cucumber::Runner.run_tests(*args)
    end

    it "uses TEST_ENV_NUMBER=blank when called for process 0" do
      ParallelTests::Cucumber::Runner.should_receive(:open).with{|x,y| x=~/TEST_ENV_NUMBER= /}.and_return mocked_process
      call(['xxx'],0,22,{})
    end

    it "uses TEST_ENV_NUMBER=2 when called for process 1" do
      ParallelTests::Cucumber::Runner.should_receive(:open).with{|x,y| x=~/TEST_ENV_NUMBER=2/}.and_return mocked_process
      call(['xxx'],1,22,{})
    end

    it 'sets PARALLEL_TEST_GROUPS so child processes know that they are being run under parallel_tests' do
      ParallelTests::Cucumber::Runner.should_receive(:open).with{|x,y| x=~/PARALLEL_TEST_GROUPS=22/}.and_return mocked_process
      call(['xxx'],1,22,{})
    end

    it "allows to override runner executable via PARALLEL_TESTS_EXECUTABLE" do
      ENV['PARALLEL_TESTS_EXECUTABLE'] = 'script/custom_rspec'
      ParallelTests::Cucumber::Runner.should_receive(:open).with{|x,y| x=~/script\/custom_rspec/}.and_return mocked_process
      call(['xxx'],1,22,{})
      ENV.delete('PARALLEL_TESTS_EXECUTABLE')
    end

    it "returns the output" do
      io = open('spec/spec_helper.rb')
      $stdout.stub!(:print)
      ParallelTests::Cucumber::Runner.should_receive(:open).and_return io
      call(['xxx'],1,22,{})[:stdout].should =~ /\$LOAD_PATH << File/
    end

    it "runs bundle exec cucumber when on bundler 0.9" do
      ParallelTests.stub!(:bundler_enabled?).and_return true
      ParallelTests::Cucumber::Runner.should_receive(:open).with{|x,y| x =~ %r{bundle exec cucumber}}.and_return mocked_process
      call(['xxx'],1,22,{})
    end

    it "runs script/cucumber when script/cucumber is found" do
      ParallelTests::Cucumber::Runner.should_receive(:open).with{|x,y| x =~ %r{script/cucumber}}.and_return mocked_process
      call(['xxx'],1,22,{})
    end

    it "runs cucumber by default" do
      File.stub!(:file?).with('script/cucumber').and_return false
      ParallelTests::Cucumber::Runner.should_receive(:open).with{|x,y| x !~ %r{(script/cucumber)|(bundle exec cucumber)}}.and_return mocked_process
      call(['xxx'],1,22,{})
    end

    it "uses options passed in" do
      ParallelTests::Cucumber::Runner.should_receive(:open).with{|x,y| x =~ %r{script/cucumber .* -p default}}.and_return mocked_process
      call(['xxx'],1,22,:test_options => '-p default')
    end

    context "with parallel profile in config/cucumber.yml" do
      before do
        file_contents = 'parallel: -f progress'
        Dir.stub(:glob).and_return ['config/cucumber.yml']
        File.stub(:read).with('config/cucumber.yml').and_return file_contents
      end

      it "uses parallel profile" do
        ParallelTests::Cucumber::Runner.should_receive(:open).with{|x,y| x =~ %r{script/cucumber .* foo bar --profile parallel "xxx"}}.and_return mocked_process
        call(['xxx'],1,22, :test_options => 'foo bar')
      end

      it "uses given profile via --profile" do
        ParallelTests::Cucumber::Runner.should_receive(:open).with{|x,y| x =~ %r{script/cucumber .* --profile foo "xxx"$}}.and_return mocked_process
        call(['xxx'],1,22, :test_options => '--profile foo')
      end

      it "uses given profile via -p" do
        ParallelTests::Cucumber::Runner.should_receive(:open).with{|x,y| x =~ %r{script/cucumber .* -p foo "xxx"$}}.and_return mocked_process
        call(['xxx'],1,22, :test_options => '-p foo')
      end
    end

    it "does not use parallel profile if config/cucumber.yml does not contain it" do
      file_contents = 'blob: -f progress'
      ParallelTests::Cucumber::Runner.should_receive(:open).with{|x,y| x =~ %r{script/cucumber .* foo bar}}.and_return mocked_process
      Dir.should_receive(:glob).and_return ['config/cucumber.yml']
      File.should_receive(:read).with('config/cucumber.yml').and_return file_contents
      call(['xxx'],1,22,:test_options => 'foo bar')
    end

    it "does not use the parallel profile if config/cucumber.yml does not exist" do
      ParallelTests::Cucumber::Runner.should_receive(:open).with{|x,y| x =~ %r{script/cucumber .*}}.and_return mocked_process
      Dir.should_receive(:glob).and_return []
      call(['xxx'],1,22,{})
    end
  end

  describe :line_is_result? do
    it "should match lines with only one scenario" do
      line = "1 scenario (1 failed)"
      ParallelTests::Cucumber::Runner.line_is_result?(line).should be_true
    end

    it "should match lines with multiple scenarios" do
      line = "2 scenarios (1 failed, 1 passed)"
      ParallelTests::Cucumber::Runner.line_is_result?(line).should be_true
    end

    it "should match lines with only one step" do
      line = "1 step (1 failed)"
      ParallelTests::Cucumber::Runner.line_is_result?(line).should be_true
    end

    it "should match lines with multiple steps" do
      line = "5 steps (1 failed, 4 passed)"
      ParallelTests::Cucumber::Runner.line_is_result?(line).should be_true
    end

    it "should not match other lines" do
      line = '    And I should have "2" emails                                # features/step_definitions/user_steps.rb:25'
      ParallelTests::Cucumber::Runner.line_is_result?(line).should be_false
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

And I should not see "foo"                                       # features/step_definitions/webrat_steps.rb:87

1 scenario (1 passed)
1 step (1 passed)

EOF
      ParallelTests::Cucumber::Runner.find_results(output).should == ["7 scenarios (3 failed, 4 passed)", "33 steps (3 failed, 2 skipped, 28 passed)", "4 scenarios (4 passed)", "40 steps (40 passed)", "1 scenario (1 passed)", "1 step (1 passed)"]
    end
  end

  describe :summarize_results do
    def call(*args)
      ParallelTests::Cucumber::Runner.summarize_results(*args)
    end

    it "sums up results for scenarios and steps separately from each other" do
      results = ["7 scenarios (3 failed, 4 passed)", "33 steps (3 failed, 2 skipped, 28 passed)", "4 scenarios (4 passed)",
                 "40 steps (40 passed)", "1 scenario (1 passed)", "1 step (1 passed)"]
      call(results).should == "12 scenarios (3 failed, 9 passed)\n74 steps (3 failed, 2 skipped, 69 passed)"
    end

    it "adds same results with plurals" do
      results = ["1 scenario (1 passed)", "2 steps (2 passed)",
                 "2 scenarios (2 passed)", "7 steps (7 passed)"]
      call(results).should == "3 scenarios (3 passed)\n9 steps (9 passed)"
    end

    it "adds non-similar results" do
      results = ["1 scenario (1 passed)", "1 step (1 passed)",
                 "2 scenarios (1 failed, 1 pending)", "2 steps (1 failed, 1 pending)"]
      call(results).should == "3 scenarios (1 failed, 1 pending, 1 passed)\n3 steps (1 failed, 1 pending, 1 passed)"
    end

    it "does not pluralize 1" do
      call(["1 scenario (1 passed)", "1 step (1 passed)"]).should == "1 scenario (1 passed)\n1 step (1 passed)"
    end
  end
end
