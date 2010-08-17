require File.dirname(__FILE__) + '/spec_helper'

describe ParallelSpecs do
  test_tests_in_groups(ParallelSpecs, 'spec', '_spec.rb')

  describe :run_tests do
    before do
      File.stub!(:file?).with('.bundle/environment.rb').and_return false
      File.stub!(:file?).with('script/spec').and_return true
      File.stub!(:file?).with('spec/spec.opts').and_return true
      File.stub!(:file?).with('spec/parallel_spec.opts').and_return false
    end

    it "uses TEST_ENV_NUMBER=blank when called for process 0" do
      ParallelSpecs.should_receive(:open).with{|x,y|x=~/TEST_ENV_NUMBER= /}.and_return mocked_process
      ParallelSpecs.run_tests(['xxx'],0,'')
    end

    it "uses TEST_ENV_NUMBER=2 when called for process 1" do
      ParallelSpecs.should_receive(:open).with{|x,y| x=~/TEST_ENV_NUMBER=2/}.and_return mocked_process
      ParallelSpecs.run_tests(['xxx'],1,'')
    end

    it "runs with color when called from cmdline" do
      ParallelSpecs.should_receive(:open).with{|x,y| x=~/RSPEC_COLOR=1/}.and_return mocked_process
      $stdout.should_receive(:tty?).and_return true
      ParallelSpecs.run_tests(['xxx'],1,'')
    end

    it "runs without color when not called from cmdline" do
      ParallelSpecs.should_receive(:open).with{|x,y| x !~ /RSPEC_COLOR/}.and_return mocked_process
      $stdout.should_receive(:tty?).and_return false
      ParallelSpecs.run_tests(['xxx'],1,'')
    end

    it "run bundle exec spec when on bundler 0.9 and rspec 1" do
      File.stub!(:file?).with('script/spec').and_return false
      ParallelSpecs.stub!(:bundler_enabled?).and_return true
      ParallelSpecs.stub!(:run).with("bundle show rspec").and_return "/foo/bar/rspec-1.0.2"
      ParallelSpecs.should_receive(:open).with{|x,y| x =~ %r{bundle exec spec}}.and_return mocked_process
      ParallelSpecs.run_tests(['xxx'],1,'')
    end

    it "run bundle exec rspec when on bundler 0.9 and rspec 2" do
      File.stub!(:file?).with('script/spec').and_return false
      ParallelSpecs.stub!(:bundler_enabled?).and_return true
      ParallelSpecs.stub!(:run).with("bundle show rspec").and_return "/foo/bar/rspec-2.0.2"
      ParallelSpecs.should_receive(:open).with{|x,y| x =~ %r{bundle exec rspec}}.and_return mocked_process
      ParallelSpecs.run_tests(['xxx'],1,'')
    end

    it "runs script/spec when script/spec can be found" do
      File.should_receive(:file?).with('script/spec').and_return true
      ParallelSpecs.should_receive(:open).with{|x,y| x =~ %r{script/spec}}.and_return mocked_process
      ParallelSpecs.run_tests(['xxx'],1,'')
    end

    it "runs spec when script/spec cannot be found" do
      File.stub!(:file?).with('script/spec').and_return false
      ParallelSpecs.should_receive(:open).with{|x,y| x !~ %r{(script/spec)|(bundle exec spec)}}.and_return mocked_process
      ParallelSpecs.run_tests(['xxx'],1,'')
    end

    it "uses no -O when no opts where found" do
      File.stub!(:file?).with('spec/spec.opts').and_return false
      ParallelSpecs.should_receive(:open).with{|x,y| x !~ %r{spec/spec.opts}}.and_return mocked_process
      ParallelSpecs.run_tests(['xxx'],1,'')
    end

    it "uses spec/spec.opts when found" do
      ParallelSpecs.should_receive(:open).with{|x,y| x =~ %r{script/spec\s+-O spec/spec.opts}}.and_return mocked_process
      ParallelSpecs.run_tests(['xxx'],1,'')
    end

    it "uses spec/parallel_spec.opts when found" do
      File.should_receive(:file?).with('spec/parallel_spec.opts').and_return true
      ParallelSpecs.should_receive(:open).with{|x,y| x =~ %r{script/spec\s+-O spec/parallel_spec.opts}}.and_return mocked_process
      ParallelSpecs.run_tests(['xxx'],1,'')
    end

    it "uses options passed in" do
      ParallelSpecs.should_receive(:open).with{|x,y| x =~ %r{script/spec -f n}}.and_return mocked_process
      ParallelSpecs.run_tests(['xxx'],1,'-f n')
    end

    it "returns the output" do
      io = open('spec/spec_helper.rb')
      ParallelSpecs.stub!(:print)
      ParallelSpecs.should_receive(:open).and_return io
      ParallelSpecs.run_tests(['xxx'],1,'').should =~ /\$LOAD_PATH << File/
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

  describe :failed do
    it "fails with single failed specs" do
      ParallelSpecs.failed?(['0 examples, 0 failures, 0 pending','1 examples, 1 failure, 1 pending']).should == true
    end

    it "fails with multiple failed specs" do
      ParallelSpecs.failed?(['0 examples, 1 failure, 0 pending','1 examples, 111 failures, 1 pending']).should == true
    end

    it "does not fail with successful specs" do
      ParallelSpecs.failed?(['0 examples, 0 failures, 0 pending','1 examples, 0 failures, 1 pending']).should == false
    end

    it "does fail with 10 failures" do
      ParallelSpecs.failed?(['0 examples, 10 failures, 0 pending','1 examples, 0 failures, 1 pending']).should == true
    end

  end
end
