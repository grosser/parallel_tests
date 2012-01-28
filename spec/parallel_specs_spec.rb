require 'spec_helper'
require 'parallel_specs/spec_runtime_logger'
require 'parallel_specs/spec_summary_logger'
require 'parallel_specs/spec_failures_logger'

describe ParallelSpecs do
  test_tests_in_groups(ParallelSpecs, 'spec', '_spec.rb')

  describe :run_tests do
    before do
      File.stub!(:file?).with('script/spec').and_return false
      File.stub!(:file?).with('spec/spec.opts').and_return false
      File.stub!(:file?).with('spec/parallel_spec.opts').and_return false
      File.stub!(:file?).with('.rspec_parallel').and_return false
      ParallelSpecs.stub!(:bundler_enabled?).and_return false
    end

    it "uses TEST_ENV_NUMBER=blank when called for process 0" do
      ParallelSpecs.should_receive(:open).with{|x,y|x=~/TEST_ENV_NUMBER= /}.and_return mocked_process
      ParallelSpecs.run_tests(['xxx'],0,{})
    end

    it "uses TEST_ENV_NUMBER=2 when called for process 1" do
      ParallelSpecs.should_receive(:open).with{|x,y| x=~/TEST_ENV_NUMBER=2/}.and_return mocked_process
      ParallelSpecs.run_tests(['xxx'],1,{})
    end

    it "runs with color when called from cmdline" do
      ParallelSpecs.should_receive(:open).with{|x,y| x=~/ --tty /}.and_return mocked_process
      $stdout.should_receive(:tty?).and_return true
      ParallelSpecs.run_tests(['xxx'],1,{})
    end

    it "runs without color when not called from cmdline" do
      ParallelSpecs.should_receive(:open).with{|x,y| x !~ / --tty /}.and_return mocked_process
      $stdout.should_receive(:tty?).and_return false
      ParallelSpecs.run_tests(['xxx'],1,{})
    end

    it "runs with color for rspec 1 when called for the cmdline" do
      File.should_receive(:file?).with('script/spec').and_return true
      ParallelSpecs.should_receive(:open).with{|x,y| x=~/ RSPEC_COLOR=1 /}.and_return mocked_process
      $stdout.should_receive(:tty?).and_return true
      ParallelSpecs.run_tests(['xxx'],1,{})
    end

    it "runs without color for rspec 1 when not called for the cmdline" do
      File.should_receive(:file?).with('script/spec').and_return true
      ParallelSpecs.should_receive(:open).with{|x,y| x !~ / RSPEC_COLOR=1 /}.and_return mocked_process
      $stdout.should_receive(:tty?).and_return false
      ParallelSpecs.run_tests(['xxx'],1,{})
    end

    it "run bundle exec spec when on bundler rspec 1" do
      File.stub!(:file?).with('script/spec').and_return false
      ParallelSpecs.stub!(:bundler_enabled?).and_return true
      ParallelSpecs.stub!(:run).with("bundle show rspec").and_return "/foo/bar/rspec-1.0.2"
      ParallelSpecs.should_receive(:open).with{|x,y| x =~ %r{bundle exec spec}}.and_return mocked_process
      ParallelSpecs.run_tests(['xxx'],1,{})
    end

    it "run bundle exec rspec when on bundler rspec 2" do
      File.stub!(:file?).with('script/spec').and_return false
      ParallelSpecs.stub!(:bundler_enabled?).and_return true
      ParallelSpecs.stub!(:run).with("bundle show rspec").and_return "/foo/bar/rspec-2.0.2"
      ParallelSpecs.should_receive(:open).with{|x,y| x =~ %r{bundle exec rspec}}.and_return mocked_process
      ParallelSpecs.run_tests(['xxx'],1,{})
    end

    it "runs script/spec when script/spec can be found" do
      File.should_receive(:file?).with('script/spec').and_return true
      ParallelSpecs.should_receive(:open).with{|x,y| x =~ %r{script/spec}}.and_return mocked_process
      ParallelSpecs.run_tests(['xxx'],1,{})
    end

    it "runs spec when script/spec cannot be found" do
      File.stub!(:file?).with('script/spec').and_return false
      ParallelSpecs.should_receive(:open).with{|x,y| x !~ %r{script/spec}}.and_return mocked_process
      ParallelSpecs.run_tests(['xxx'],1,{})
    end

    it "uses no -O when no opts where found" do
      File.stub!(:file?).with('spec/spec.opts').and_return false
      ParallelSpecs.should_receive(:open).with{|x,y| x !~ %r{spec/spec.opts}}.and_return mocked_process
      ParallelSpecs.run_tests(['xxx'],1,{})
    end

    it "uses -O spec/spec.opts when found (with script/spec)" do
      File.stub!(:file?).with('script/spec').and_return true
      File.stub!(:file?).with('spec/spec.opts').and_return true
      ParallelSpecs.should_receive(:open).with{|x,y| x =~ %r{script/spec\s+ -O spec/spec.opts}}.and_return mocked_process
      ParallelSpecs.run_tests(['xxx'],1,{})
    end

    it "uses -O spec/parallel_spec.opts when found (with script/spec)" do
      File.stub!(:file?).with('script/spec').and_return true
      File.should_receive(:file?).with('spec/parallel_spec.opts').and_return true
      ParallelSpecs.should_receive(:open).with{|x,y| x =~ %r{script/spec\s+ -O spec/parallel_spec.opts}}.and_return mocked_process
      ParallelSpecs.run_tests(['xxx'],1,{})
    end

    it "uses -O .rspec_parallel when found (with script/spec)" do
      File.stub!(:file?).with('script/spec').and_return true
      File.should_receive(:file?).with('.rspec_parallel').and_return true
      ParallelSpecs.should_receive(:open).with{|x,y| x =~ %r{script/spec\s+ -O .rspec_parallel}}.and_return mocked_process
      ParallelSpecs.run_tests(['xxx'],1,{})
    end

    it "uses -O spec/parallel_spec.opts with rspec1" do
      File.should_receive(:file?).with('spec/parallel_spec.opts').and_return true

      ParallelSpecs.stub!(:bundler_enabled?).and_return true
      ParallelSpecs.stub!(:run).with("bundle show rspec").and_return "/foo/bar/rspec-1.0.2"

      ParallelSpecs.should_receive(:open).with{|x,y| x =~ %r{spec\s+ -O spec/parallel_spec.opts}}.and_return mocked_process
      ParallelSpecs.run_tests(['xxx'],1,{})
    end

    it "uses -O spec/parallel_spec.opts with rspec2" do
      File.should_receive(:file?).with('spec/parallel_spec.opts').and_return true

      ParallelSpecs.stub!(:bundler_enabled?).and_return true
      ParallelSpecs.stub!(:run).with("bundle show rspec").and_return "/foo/bar/rspec-2.4.2"

      ParallelSpecs.should_receive(:open).with{|x,y| x =~ %r{rspec\s+ --color --tty -O spec/parallel_spec.opts}}.and_return mocked_process
      ParallelSpecs.run_tests(['xxx'],1,{})
    end

    it "uses options passed in" do
      ParallelSpecs.should_receive(:open).with{|x,y| x =~ %r{rspec -f n}}.and_return mocked_process
      ParallelSpecs.run_tests(['xxx'],1, :test_options => '-f n')
    end

    it "returns the output" do
      io = open('spec/spec_helper.rb')
      ParallelSpecs.stub!(:print)
      ParallelSpecs.should_receive(:open).and_return io
      ParallelSpecs.run_tests(['xxx'],1,{})[:stdout].should =~ /\$LOAD_PATH << File/
    end
  end

  describe :find_results do
    it "finds multiple results in spec output" do
      output = <<EOF
....F...
..
failute fsddsfsd
...
ff.**..
0 examples, 0 failures, 0 pending
ff.**..
1 example, 1 failure, 1 pending
EOF

      ParallelSpecs.find_results(output).should == ['0 examples, 0 failures, 0 pending','1 example, 1 failure, 1 pending']
    end

    it "is robust against scrambeled output" do
      output = <<EOF
....F...
..
failute fsddsfsd
...
ff.**..
0 exFampl*es, 0 failures, 0 pend.ing
ff.**..
1 exampF.les, 1 failures, 1 pend.ing
EOF

      ParallelSpecs.find_results(output).should == ['0 examples, 0 failures, 0 pending','1 examples, 1 failures, 1 pending']
    end
  end
end
