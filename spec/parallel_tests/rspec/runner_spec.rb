require "spec_helper"
require "parallel_tests/rspec/runner"

describe ParallelTests::RSpec::Runner do
  test_tests_in_groups(ParallelTests::RSpec::Runner, '_spec.rb')

  describe '.run_tests' do
    before do
      allow(File).to receive(:file?).with('spec/spec.opts').and_return false
      allow(File).to receive(:file?).with('spec/parallel_spec.opts').and_return false
      allow(File).to receive(:file?).with('.rspec_parallel').and_return false
      allow(ParallelTests).to receive(:bundler_enabled?).and_return false
    end

    def call(*args)
      ParallelTests::RSpec::Runner.run_tests(*args)
    end

    it "runs command using nice when specifed" do
      expect(ParallelTests::Test::Runner).to receive(:execute_command_and_capture_output)do |a,b,c|
        expect(b).to match(%r{^nice rspec})
      end

      call('xxx', 1, 22, :nice => true)
    end

    it "runs with color when called from cmdline" do
      should_run_with %r{ --tty}
      expect($stdout).to receive(:tty?).and_return true
      call('xxx', 1, 22, {})
    end

    it "runs without color when not called from cmdline" do
      should_not_run_with %r{ --tty}
      expect($stdout).to receive(:tty?).and_return false
      call('xxx', 1, 22, {})
    end

    it "uses bin/rspec when present" do
      allow(File).to receive(:exist?).with('bin/rspec').and_return true
      should_run_with %r{bin/rspec}
      call('xxx', 1, 22, {})
    end

    it "uses no -O when no opts where found" do
      allow(File).to receive(:file?).with('spec/spec.opts').and_return false
      should_not_run_with %r{spec/spec.opts}
      call('xxx', 1, 22, {})
    end

    it "uses -O spec/parallel_spec.opts with rspec2" do
      skip if RUBY_PLATFORM == "java" # FIXME not sure why, but fails on travis
      expect(File).to receive(:file?).with('spec/parallel_spec.opts').and_return true

      allow(ParallelTests).to receive(:bundler_enabled?).and_return true
      allow(ParallelTests::RSpec::Runner).to receive(:run).with("bundle show rspec-core").and_return "/foo/bar/rspec-core-2.4.2"

      should_run_with %r{rspec\s+--color --tty -O spec/parallel_spec.opts}
      call('xxx', 1, 22, {})
    end

    it "uses options passed in" do
      should_run_with %r{rspec -f n}
      call('xxx', 1, 22, :test_options => '-f n')
    end

    it "returns the output" do
      expect(ParallelTests::RSpec::Runner).to receive(:execute_command).and_return :x => 1
      expect(call('xxx', 1, 22, {})).to eq({:x => 1})
    end
  end

  describe '.find_results' do
    def call(*args)
      ParallelTests::RSpec::Runner.find_results(*args)
    end

    it "finds multiple results in spec output" do
      output = <<-OUT.gsub(/^        /, '')
        ....F...
        ..
        failute fsddsfsd
        ...
        ff.**..
        0 examples, 0 failures, 0 pending
        ff.**..
        1 example, 1 failure, 1 pending
      OUT

      expect(call(output)).to eq(['0 examples, 0 failures, 0 pending','1 example, 1 failure, 1 pending'])
    end

    it "does not mistakenly count 'pending' failures as real failures" do
      output = <<-OUT.gsub(/^        /, '')
        .....
        Pending: (Failures listed here are expected and do not affect your suite's status)

        1) Foo
           Got 1 failure and 1 other error:

           1.1) Failure/Error:
                  Bar
                  Baz

           1.2) Failure/Error:
                  Bar
                  Baz
        1 examples, 0 failures, 1 pending
      OUT

      expect(call(output)).to eq(['1 examples, 0 failures, 1 pending'])
    end
  end

  describe ".find_tests" do
    def call(*args)
      ParallelTests::RSpec::Runner.send(:find_tests, *args)
    end

    it "doesn't find bakup files with the same name as test files" do
      with_files(['a/x_spec.rb','a/x_spec.rb.bak']) do |root|
        expect(call(["#{root}/"])).to eq([
          "#{root}/a/x_spec.rb",
        ])
      end
    end
  end

  describe ".command_with_seed" do
    def call(args)
      base = "ruby -Ilib:test test/minitest/test_minitest_unit.rb"
      result = ParallelTests::RSpec::Runner.command_with_seed("#{base}#{args}", 555)
      result.sub(base, '')
    end

    it "adds the randomized seed" do
      expect(call("")).to eq(" --seed 555")
    end

    it "does not duplicate seed" do
      expect(call(" --seed 123")).to eq(" --seed 555")
    end

    it "does not match strange seeds stuff" do
      expect(call(" --seed 123asdasd")).to eq(" --seed 123asdasd --seed 555")
    end

    it "does not match non seeds" do
      expect(call(" --seedling 123")).to eq(" --seedling 123 --seed 555")
    end

    it "does not duplicate random" do
      expect(call(" --order random")).to eq(" --seed 555")
    end

    it "does not duplicate rand" do
      expect(call(" --order rand")).to eq(" --seed 555")
    end

    it "does not duplicate rand with seed" do
      expect(call(" --order rand:123")).to eq(" --seed 555")
    end

    it "does not duplicate random with seed" do
      expect(call(" --order random:123")).to eq(" --seed 555")
    end
  end
end
