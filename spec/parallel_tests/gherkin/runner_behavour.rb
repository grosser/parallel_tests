require "spec_helper"
require "parallel_tests/gherkin_bdd/runner"

shared_examples_for 'gherkin runners' do
  test_tests_in_groups(RUNNER_CLASS, 'features', ".feature")

  describe :run_tests do
    before do
      ParallelTests.stub!(:bundler_enabled?).and_return false
      File.stub!(:file?).with('.bundle/environment.rb').and_return false
      File.stub!(:file?).with("script/#{NAME}").and_return true
    end

    def call(*args)
      RUNNER_CLASS.run_tests(*args)
    end

    def should_run_with(regex)
      ParallelTests::Test::Runner.should_receive(:execute_command).with { |a, b, c, d| a =~ regex }
    end

    it "allows to override runner executable via PARALLEL_TESTS_EXECUTABLE" do
      ENV['PARALLEL_TESTS_EXECUTABLE'] = 'script/custom_rspec'
      should_run_with /script\/custom_rspec/
      call(['xxx'], 1, 22, {})
      ENV.delete('PARALLEL_TESTS_EXECUTABLE')
    end

    it "runs bundle exec #{NAME} when on bundler 0.9" do
      ParallelTests.stub!(:bundler_enabled?).and_return true
      should_run_with %r{bundle exec #{NAME}}
      call(['xxx'], 1, 22, {})
    end

    it "runs script/#{NAME} when script/#{NAME} is found" do
      should_run_with %r{script/#{NAME}}
      call(['xxx'], 1, 22, {})
    end

    it "runs #{NAME} by default" do
      File.stub!(:file?).with("script/#{NAME}").and_return false
      should_run_with %r{^#{NAME}}
      call(['xxx'], 1, 22, {})
    end

    it "uses bin/#{NAME} when present" do
      File.stub(:exists?).with("bin/#{NAME}").and_return true
      should_run_with %r{bin/#{NAME}}
      call(['xxx'], 1, 22, {})
    end

    it "uses options passed in" do
      should_run_with %r{script/#{NAME} .* -p default}
      call(['xxx'], 1, 22, :test_options => '-p default')
    end

    it "sanitizes dangerous file names" do
      should_run_with %r{xx\\ x}
      call(['xx x'], 1, 22, {})
    end

    context "with parallel profile in config/#{NAME}.yml" do
      before do
        file_contents = 'parallel: -f progress'
        Dir.stub(:glob).and_return ["config/#{NAME}.yml"]
        File.stub(:read).with("config/#{NAME}.yml").and_return file_contents
      end

      it "uses parallel profile" do
        should_run_with %r{script/#{NAME} .* foo bar --profile parallel xxx}
        call(['xxx'], 1, 22, :test_options => 'foo bar')
      end

      it "uses given profile via --profile" do
        should_run_with %r{script/#{NAME} .* --profile foo xxx$}
        call(['xxx'], 1, 22, :test_options => '--profile foo')
      end

      it "uses given profile via -p" do
        should_run_with %r{script/#{NAME} .* -p foo xxx$}
        call(['xxx'], 1, 22, :test_options => '-p foo')
      end
    end

    it "does not use parallel profile if config/#{NAME}.yml does not contain it" do
      file_contents = 'blob: -f progress'
      should_run_with %r{script/#{NAME} .* foo bar}
      Dir.should_receive(:glob).and_return ["config/#{NAME}.yml"]
      File.should_receive(:read).with("config/#{NAME}.yml").and_return file_contents
      call(['xxx'], 1, 22, :test_options => 'foo bar')
    end

    it "does not use the parallel profile if config/#{NAME}.yml does not exist" do
      should_run_with %r{script/#{NAME}} # TODO this test looks useless...
      Dir.should_receive(:glob).and_return []
      call(['xxx'], 1, 22, {})
    end
  end

  describe :line_is_result? do
    it "should match lines with only one scenario" do
      line = "1 scenario (1 failed)"
      RUNNER_CLASS.line_is_result?(line).should be_true
    end

    it "should match lines with multiple scenarios" do
      line = "2 scenarios (1 failed, 1 passed)"
      RUNNER_CLASS.line_is_result?(line).should be_true
    end

    it "should match lines with only one step" do
      line = "1 step (1 failed)"
      RUNNER_CLASS.line_is_result?(line).should be_true
    end

    it "should match lines with multiple steps" do
      line = "5 steps (1 failed, 4 passed)"
      RUNNER_CLASS.line_is_result?(line).should be_true
    end

    it "should not match other lines" do
      line = '    And I should have "2" emails                                # features/step_definitions/user_steps.rb:25'
      RUNNER_CLASS.line_is_result?(line).should be_false
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
      RUNNER_CLASS.find_results(output).should == ["7 scenarios (3 failed, 4 passed)", "33 steps (3 failed, 2 skipped, 28 passed)", "4 scenarios (4 passed)", "40 steps (40 passed)", "1 scenario (1 passed)", "1 step (1 passed)"]
    end
  end

  describe :summarize_results do
    def call(*args)
      RUNNER_CLASS.summarize_results(*args)
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
