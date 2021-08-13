# frozen_string_literal: true
require "spec_helper"
require "parallel_tests/gherkin/runner"

shared_examples_for 'gherkin runners' do
  describe :run_tests do
    before do
      allow(ParallelTests).to receive(:bundler_enabled?).and_return false
      allow(File).to receive(:file?).with('.bundle/environment.rb').and_return false
      allow(File).to receive(:file?).with("script/#{runner_name}").and_return true
    end

    def call(*args)
      runner_class.run_tests(*args)
    end

    it "allows to override runner executable via PARALLEL_TESTS_EXECUTABLE" do
      ENV['PARALLEL_TESTS_EXECUTABLE'] = 'script/custom_rspec'
      should_run_with(%r{script/custom_rspec})
      call(['xxx'], 1, 22, {})
    end

    it "permits setting env options" do
      expect(ParallelTests::Test::Runner).to receive(:execute_command) do |_, _, _, options|
        expect(options[:env]["TEST"]).to eq("ME")
      end
      call(['xxx'], 1, 22, { env: { 'TEST' => 'ME' } })
    end

    it "runs bundle exec {runner_name} when on bundler 0.9" do
      allow(ParallelTests).to receive(:bundler_enabled?).and_return true
      should_run_with /bundle exec #{runner_name}/
      call(['xxx'], 1, 22, {})
    end

    it "runs script/{runner_name} when script/{runner_name} is found" do
      should_run_with %r{script/#{runner_name}}
      call(['xxx'], 1, 22, {})
    end

    it "runs {runner_name} by default" do
      allow(File).to receive(:file?).with("script/#{runner_name}").and_return false
      should_run_with /^#{runner_name}/
      call(['xxx'], 1, 22, {})
    end

    it "uses bin/{runner_name} when present" do
      allow(File).to receive(:exist?).with("bin/#{runner_name}").and_return true
      should_run_with %r{bin/#{runner_name}}
      call(['xxx'], 1, 22, {})
    end

    it "uses options passed in" do
      should_run_with %r{script/#{runner_name} .*-p default}
      call(['xxx'], 1, 22, test_options: '-p default')
    end

    it "sanitizes dangerous file runner_names" do
      if ParallelTests::WINDOWS
        should_run_with /"xx x"/
      else
        should_run_with /xx\\ x/
      end

      call(['xx x'], 1, 22, {})
    end

    context "with parallel profile in config/{runner_name}.yml" do
      before do
        file_contents = 'parallel: -f progress'
        allow(Dir).to receive(:glob).and_return ["config/#{runner_name}.yml"]
        allow(File).to receive(:read).with("config/#{runner_name}.yml").and_return file_contents
      end

      it "uses parallel profile" do
        if ParallelTests::WINDOWS
          should_run_with %r{script/#{runner_name} "xxx" .*foo bar --profile parallel}
        else
          should_run_with %r{script/#{runner_name} xxx .*foo bar --profile parallel}
        end

        call(['xxx'], 1, 22, test_options: 'foo bar')
      end

      it "uses given profile via --profile" do
        if ParallelTests::WINDOWS
          should_run_with %r{script/#{runner_name} "xxx" .*--profile foo$}
        else
          should_run_with %r{script/#{runner_name} xxx .*--profile foo$}
        end

        call(['xxx'], 1, 22, test_options: '--profile foo')
      end

      it "uses given profile via -p" do
        if ParallelTests::WINDOWS
          should_run_with %r{script/#{runner_name} "xxx" .*-p foo$}
        else
          should_run_with %r{script/#{runner_name} xxx .*-p foo$}
        end

        call(['xxx'], 1, 22, test_options: '-p foo')
      end
    end

    it "does not use parallel profile if config/{runner_name}.yml does not contain it" do
      file_contents = 'blob: -f progress'
      should_run_with %r{script/#{runner_name} .*foo bar}
      expect(Dir).to receive(:glob).and_return ["config/#{runner_name}.yml"]
      expect(File).to receive(:read).with("config/#{runner_name}.yml").and_return file_contents
      call(['xxx'], 1, 22, test_options: 'foo bar')
    end

    it "does not use the parallel profile if config/{runner_name}.yml does not exist" do
      should_run_with %r{script/#{runner_name}} # TODO: this test looks useless...
      expect(Dir).to receive(:glob).and_return []
      call(['xxx'], 1, 22, {})
    end
  end

  describe :line_is_result? do
    it "should match lines with only one scenario" do
      line = "1 scenario (1 failed)"
      expect(runner_class.line_is_result?(line)).to be_truthy
    end

    it "should match lines with multiple scenarios" do
      line = "2 scenarios (1 failed, 1 passed)"
      expect(runner_class.line_is_result?(line)).to be_truthy
    end

    it "should match lines with only one step" do
      line = "1 step (1 failed)"
      expect(runner_class.line_is_result?(line)).to be_truthy
    end

    it "should match lines with multiple steps" do
      line = "5 steps (1 failed, 4 passed)"
      expect(runner_class.line_is_result?(line)).to be_truthy
    end

    it "should not match other lines" do
      line = '    And I should have "2" emails                                # features/step_definitions/user_steps.rb:25'
      expect(runner_class.line_is_result?(line)).to be_falsey
    end
  end

  describe :find_results do
    it "finds multiple results in test output" do
      output = <<~EOF
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
      expect(runner_class.find_results(output)).to eq(
        [
          "7 scenarios (3 failed, 4 passed)",
          "33 steps (3 failed, 2 skipped, 28 passed)",
          "4 scenarios (4 passed)",
          "40 steps (40 passed)",
          "1 scenario (1 passed)", "1 step (1 passed)"
        ]
      )
    end
  end

  describe :summarize_results do
    def call(*args)
      runner_class.summarize_results(*args)
    end

    it "sums up results for scenarios and steps separately from each other" do
      results = [
        "7 scenarios (2 failed, 1 flaky, 4 passed)",
        "33 steps (3 failed, 2 skipped, 28 passed)",
        "4 scenarios (4 passed)", "40 steps (40 passed)",
        "1 scenario (1 passed)", "1 step (1 passed)"
      ]
      expect(call(results)).to eq("12 scenarios (2 failed, 1 flaky, 9 passed)\n74 steps (3 failed, 2 skipped, 69 passed)")
    end

    it "adds same results with plurals" do
      results = [
        "1 scenario (1 passed)", "2 steps (2 passed)",
        "2 scenarios (2 passed)", "7 steps (7 passed)"
      ]
      expect(call(results)).to eq("3 scenarios (3 passed)\n9 steps (9 passed)")
    end

    it "adds non-similar results" do
      results = [
        "1 scenario (1 passed)", "1 step (1 passed)",
        "2 scenarios (1 failed, 1 pending)", "2 steps (1 failed, 1 pending)"
      ]
      expect(call(results)).to eq("3 scenarios (1 failed, 1 pending, 1 passed)\n3 steps (1 failed, 1 pending, 1 passed)")
    end

    it "does not pluralize 1" do
      expect(call(["1 scenario (1 passed)", "1 step (1 passed)"])).to eq("1 scenario (1 passed)\n1 step (1 passed)")
    end
  end

  describe 'grouping by scenarios for cucumber' do
    def call(*args)
      runner_class.send(:run_tests, *args)
    end

    it 'groups cucumber invocation by feature files to achieve correct cucumber hook behaviour' do
      test_files = ['features/a.rb:23', 'features/a.rb:44', 'features/b.rb:12']

      expect(ParallelTests::Test::Runner).to receive(:execute_command) do |a, _b, _c, _d|
        argv = a.split.last(2)

        if ParallelTests::WINDOWS
          expect(argv).to eq(['"features/a.rb:23:44"', '"features/b.rb:12"'])
        else
          expect(argv).to eq(["features/a.rb:23:44", "features/b.rb:12"])
        end
      end

      call(test_files, 1, 2, { group_by: :scenarios })
    end
  end

  describe ".find_tests" do
    def call(*args)
      ParallelTests::Gherkin::Runner.send(:find_tests, *args)
    end

    it "doesn't find bakup files with the same name as test files" do
      with_files(['a/x.feature', 'a/x.feature.bak']) do |root|
        expect(call(["#{root}/"])).to eq(
          [
            "#{root}/a/x.feature"
          ]
        )
      end
    end
  end
end
