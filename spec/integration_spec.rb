require 'spec/spec_helper'

describe 'CLI' do
  before do
    `rm -rf #{folder}`
  end

  after do
    `rm -rf #{folder}`
  end

  def folder
    "/tmp/parallel_tests_tests"
  end

  def write(file, content)
    path = "#{folder}/spec/#{file}"
    `mkdir -p #{File.dirname(path)}` unless File.exist?(File.dirname(path))
    File.open(path, 'w'){|f| f.write content }
    path
  end

  def bin_folder
    "#{File.expand_path(File.dirname(__FILE__))}/../bin"
  end

  def executable
    "#{bin_folder}/parallel_test"
  end

  def run_specs(options={})
    `cd #{folder} && #{executable} -t spec -n #{options[:processes]||2} #{options[:add]} 2>&1 && echo 'i ran!'`
  end

  it "runs tests in parallel" do
    write 'xxx_spec.rb', 'describe("it"){it("should"){puts "TEST1"}}'
    write 'xxx2_spec.rb', 'describe("it"){it("should"){puts "TEST2"}}'
    result = run_specs

    # test ran and gave their puts
    result.should include('TEST1')
    result.should include('TEST2')

    # all results present
    result.scan('1 example, 0 failure').size.should == 4 # 2 results + 2 result summary
    result.scan(/Finished in \d+\.\d+ seconds/).size.should == 2
    result.scan(/Took \d+\.\d+ seconds/).size.should == 1 # parallel summary

    result.should include('i ran!')
  end

  it "fails when tests fail" do
    write 'xxx_spec.rb', 'describe("it"){it("should"){puts "TEST1"}}'
    write 'xxx2_spec.rb', 'describe("it"){it("should"){1.should == 2}}'
    result = run_specs

    result.scan('1 example, 1 failure').size.should == 2
    result.scan('1 example, 0 failure').size.should == 2
    result.should =~ /specs failed/i
    result.should_not include('i ran!')
  end

  it "can exec given commands with ENV['TEST_ENV_NUM']" do
    result = `#{executable} -e 'ruby -e "puts ENV[:TEST_ENV_NUMBER.to_s].inspect"' -n 4`
    result.split("\n").sort.should == %w["" "2" "3" "4"]
  end

  it "exists with success if all sub-processes returned success" do
    system("#{executable} -e 'cat /dev/null' -n 4").should == true
  end

  it "exists with failure if any sub-processes returned failure" do
    system("#{executable} -e 'test -e xxxx' -n 4").should == false
  end

  it "can run through parallel_spec / parallel_cucumber" do
    version = `#{executable} -v`
    `#{bin_folder}/parallel_spec -v`.should == version
    `#{bin_folder}/parallel_cucumber -v`.should == version
  end

  it "runs faster with more processes" do
    write 'xxx_spec.rb', 'describe("it"){it("should"){sleep 2}}'
    write 'xxx2_spec.rb', 'describe("it"){it("should"){sleep 2}}'
    write 'xxx3_spec.rb', 'describe("it"){it("should"){sleep 2}}'
    write 'xxx4_spec.rb', 'describe("it"){it("should"){sleep 2}}'
    write 'xxx5_spec.rb', 'describe("it"){it("should"){sleep 2}}'
    write 'xxx6_spec.rb', 'describe("it"){it("should"){sleep 2}}'
    t = Time.now
    run_specs :processes => 6
    expected = 10
    (Time.now - t).should <= expected
  end

  it "can can with given files" do
    write "x1_spec.rb", "puts '111'"
    write "x2_spec.rb", "puts '222'"
    write "x3_spec.rb", "puts '333'"
    result = run_specs(:add => 'spec/x1_spec.rb spec/x3_spec.rb')
    result.should include('111')
    result.should include('333')
    result.should_not include('222')
  end

  it "can run with test-options" do
    write "x1_spec.rb", ""
    write "x2_spec.rb", ""
    result = run_specs(:add => "--test-options ' --version'", :processes => 2)
    result.should =~ /\d+\.\d+\.\d+\..*\d+\.\d+\.\d+\./m # prints version twice
  end
end