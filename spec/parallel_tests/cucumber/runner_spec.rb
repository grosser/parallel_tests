require 'spec_helper'

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
      call(['xxx'],0,{})
    end

    it "uses TEST_ENV_NUMBER=2 when called for process 1" do
      ParallelTests::Cucumber::Runner.should_receive(:open).with{|x,y| x=~/TEST_ENV_NUMBER=2/}.and_return mocked_process
      call(['xxx'],1,{})
    end

    it "returns the output" do
      io = open('spec/spec_helper.rb')
      $stdout.stub!(:print)
      ParallelTests::Cucumber::Runner.should_receive(:open).and_return io
      call(['xxx'],1,{})[:stdout].should =~ /\$LOAD_PATH << File/
    end

    it "runs bundle exec cucumber when on bundler 0.9" do
      ParallelTests.stub!(:bundler_enabled?).and_return true
      ParallelTests::Cucumber::Runner.should_receive(:open).with{|x,y| x =~ %r{bundle exec cucumber}}.and_return mocked_process
      call(['xxx'],1,{})
    end

    it "runs script/cucumber when script/cucumber is found" do
      ParallelTests::Cucumber::Runner.should_receive(:open).with{|x,y| x =~ %r{script/cucumber}}.and_return mocked_process
      call(['xxx'],1,{})
    end

    it "runs cucumber by default" do
      File.stub!(:file?).with('script/cucumber').and_return false
      ParallelTests::Cucumber::Runner.should_receive(:open).with{|x,y| x !~ %r{(script/cucumber)|(bundle exec cucumber)}}.and_return mocked_process
      call(['xxx'],1,{})
    end

    it "uses options passed in" do
      ParallelTests::Cucumber::Runner.should_receive(:open).with{|x,y| x =~ %r{script/cucumber .* -p default}}.and_return mocked_process
      call(['xxx'],1,:test_options => '-p default')
    end

    it "uses the contents of a config/cucumber.yml file as options" do
      file_contents = 'parallel: -f progress'
      ParallelTests::Cucumber::Runner.should_receive(:open).with{|x,y| x =~ %r{script/cucumber .* -f progress}}.and_return mocked_process
      File.should_receive(:exists?).with('config/cucumber.yml').and_return true
      File.should_receive(:read).with('config/cucumber.yml').and_return file_contents
      call(['xxx'],1,{})
    end

    it "doesn't use the contents of a config/cucumber.yml file when it's not available" do
      ParallelTests::Cucumber::Runner.should_receive(:open).with{|x,y| x =~ %r{script/cucumber .*}}.and_return mocked_process
      File.should_receive(:exists?).with('config/cucumber.yml').and_return false
      call(['xxx'],1,{})
    end

    it "merges the contents of a config/cucumber.yml file with the current test options" do
      file_contents = 'parallel: -f progress'
      ParallelTests::Cucumber::Runner.should_receive(:open).with{|x,y| x =~ %r{script/cucumber .* -p default -f progress}}.and_return mocked_process
      File.should_receive(:exists?).with('config/cucumber.yml').and_return true
      File.should_receive(:read).with('config/cucumber.yml').and_return file_contents
      call(['xxx'],1,:test_options => '-p default')
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
      ParallelTests::Cucumber::Runner.find_results(output).should == ["7 scenarios (3 failed, 4 passed)", "33 steps (3 failed, 2 skipped, 28 passed)", "4 scenarios (4 passed)", "40 steps (40 passed)"]
    end
  end
end
