require "spec_helper"
require "parallel_tests/rspec/runner"

describe ParallelTests::RSpec::Runner do
  test_tests_in_groups(ParallelTests::RSpec::Runner, 'spec', '_spec.rb')

  describe :run_tests do
    before do
      File.stub!(:file?).with('script/spec').and_return false
      File.stub!(:file?).with('spec/spec.opts').and_return false
      File.stub!(:file?).with('spec/parallel_spec.opts').and_return false
      File.stub!(:file?).with('.rspec_parallel').and_return false
      ParallelTests.stub!(:bundler_enabled?).and_return false
    end

    def call(*args)
      ParallelTests::RSpec::Runner.run_tests(*args)
    end

    def should_run_with(regex)
      expect(ParallelTests::Test::Runner).to receive(:execute_command).with{|a,b,c,d| a.match(regex)}
    end

    def should_not_run_with(regex)
      expect(ParallelTests::Test::Runner).to receive(:execute_command).with{|a,b,c,d| a !~ regex}
    end

    it "runs command using nice when specifed" do
      expect{(ParallelTests::Test::Runner).to receive(:execute_command_and_capture_output).with{|a,b,c| b match( %r{^nice rspec})}}.to be_true
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

    it "runs with color for rspec 1 when called for the cmdline" do
      expect(File).to receive(:file?).with('script/spec').and_return true
      expect(ParallelTests::Test::Runner).to receive(:execute_command).with { |a, b, c, d| d[:env] == {"RSPEC_COLOR" => "1"} }
      expect($stdout).to receive(:tty?).and_return true
      call('xxx', 1, 22, {})
    end

    it "runs without color for rspec 1 when not called for the cmdline" do
      expect(File).to receive(:file?).with('script/spec').and_return true
      expect(ParallelTests::Test::Runner).to receive(:execute_command).with { |a, b, c, d| d[:env] == {} }
      expect($stdout).to receive(:tty?).and_return false
      call('xxx', 1, 22, {})
    end

    it "run bundle exec spec when on bundler rspec 1" do
      File.stub!(:file?).with('script/spec').and_return false
      ParallelTests.stub!(:bundler_enabled?).and_return true
      ParallelTests::RSpec::Runner.stub!(:run).with("bundle show rspec-core").and_return "Could not find gem 'rspec-core' in bundler."
      should_run_with %r{bundle exec spec}
      call('xxx', 1, 22, {})
    end

    it "run bundle exec rspec when on bundler rspec 2" do
      File.stub!(:file?).with('script/spec').and_return false
      ParallelTests.stub!(:bundler_enabled?).and_return true
      ParallelTests::RSpec::Runner.stub!(:run).with("bundle show rspec-core").and_return "/foo/bar/rspec-core-2.0.2"
      should_run_with %r{bundle exec rspec}
      call('xxx', 1, 22, {})
    end

    it "runs script/spec when script/spec can be found" do
      expect(File).to receive(:file?).with('script/spec').and_return true
      should_run_with %r{script/spec}
      call('xxx' ,1, 22, {})
    end

    it "runs spec when script/spec cannot be found" do
      File.stub!(:file?).with('script/spec').and_return false
      should_not_run_with %r{ script/spec}
      call('xxx', 1, 22, {})
    end

    it "uses bin/rspec when present" do
      File.stub(:exists?).with('bin/rspec').and_return true
      should_run_with %r{bin/rspec}
      call('xxx', 1, 22, {})
    end

    it "uses no -O when no opts where found" do
      File.stub!(:file?).with('spec/spec.opts').and_return false
      should_not_run_with %r{spec/spec.opts}
      call('xxx', 1, 22, {})
    end

    it "uses -O spec/spec.opts when found (with script/spec)" do
      File.stub!(:file?).with('script/spec').and_return true
      File.stub!(:file?).with('spec/spec.opts').and_return true
      should_run_with %r{script/spec\s+-O spec/spec.opts}
      call('xxx', 1, 22, {})
    end

    it "uses -O spec/parallel_spec.opts when found (with script/spec)" do
      File.stub!(:file?).with('script/spec').and_return true
      expect(File).to receive(:file?).with('spec/parallel_spec.opts').and_return true
      should_run_with %r{script/spec\s+-O spec/parallel_spec.opts}
      call('xxx', 1, 22, {})
    end

    it "uses -O .rspec_parallel when found (with script/spec)" do
      File.stub!(:file?).with('script/spec').and_return true
      expect(File).to receive(:file?).with('.rspec_parallel').and_return true
      should_run_with %r{script/spec\s+-O .rspec_parallel}
      call('xxx', 1, 22, {})
    end

    it "uses -O spec/parallel_spec.opts with rspec1" do
      expect(File).to receive(:file?).with('spec/parallel_spec.opts').and_return true

      ParallelTests.stub!(:bundler_enabled?).and_return true
      ParallelTests::RSpec::Runner.stub!(:run).with("bundle show rspec-core").and_return "Could not find gem 'rspec-core'."

      should_run_with %r{spec\s+-O spec/parallel_spec.opts}
      call('xxx', 1, 22, {})
    end

    it "uses -O spec/parallel_spec.opts with rspec2" do
      pending if RUBY_PLATFORM == "java" # FIXME not sure why, but fails on travis
      expect(File).to receive(:file?).with('spec/parallel_spec.opts').and_return true

      ParallelTests.stub!(:bundler_enabled?).and_return true
      ParallelTests::RSpec::Runner.stub!(:run).with("bundle show rspec-core").and_return "/foo/bar/rspec-core-2.4.2"

      should_run_with %r{rspec\s+--color --tty -O spec/parallel_spec.opts}
      call('xxx', 1, 22, {})
    end

    it "uses options passed in" do
      should_run_with %r{rspec -f n}
      call('xxx', 1, 22, :test_options => '-f n')
    end

    it "returns the output" do
      expect(ParallelTests::RSpec::Runner).to receive(:execute_command).and_return :x => 1
      expect(call('xxx', 1, 22, {})).to eq ({ :x => 1} )
    end
  end

  describe :find_results do
    def call(*args)
      ParallelTests::RSpec::Runner.find_results(*args)
    end

    it "finds multiple results in spec output" do
      output = "
....F...
..
failute fsddsfsd
...
ff.**..
0 examples, 0 failures, 0 pending
ff.**..
1 example, 1 failure, 1 pending
"

      expect(call(output)).to eq ['0 examples, 0 failures, 0 pending','1 example, 1 failure, 1 pending']
    end

    it "is robust against scrambeled output" do
      output = "
....F...
..
failute fsddsfsd
...
ff.**..
0 exFampl*es, 0 failures, 0 pend.ing
ff.**..
1 exampF.les, 1 failures, 1 pend.ing
"

      expect(call(output)).to eq ['0 examples, 0 failures, 0 pending','1 examples, 1 failures, 1 pending']
    end
  end

  describe ".find_tests" do
    def call(*args)
      ParallelTests::RSpec::Runner.send(:find_tests, *args)
    end

    it "doesn't find bakup files with the same name as test files" do
      with_files(['a/x_spec.rb','a/x_spec.rb.bak']) do |root|
        call(["#{root}/"]).should == [
          "#{root}/a/x_spec.rb",
        ]
      end
    end
  end
end
