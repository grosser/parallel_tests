#encoding: utf-8

require 'spec_helper'

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
    path = "#{folder}/#{file}"
    ensure_folder File.dirname(path)
    File.open(path, 'w'){|f| f.write content }
    path
  end

  def read(file)
    File.read "#{folder}/#{file}"
  end

  def bin_folder
    "#{File.expand_path(File.dirname(__FILE__))}/../bin"
  end

  def executable(options={})
    "#{bin_folder}/parallel_#{options[:type] || 'test'}"
  end

  def ensure_folder(folder)
    `mkdir -p #{folder}` unless File.exist?(folder)
  end

  def run_tests(test_folder, options={})
    ensure_folder folder
    processes = "-n #{options[:processes]||2}" unless options[:processes] == false
    command = "cd #{folder} && #{options[:export]} #{executable(options)} #{test_folder} #{processes} #{options[:add]} 2>&1"
    result = `#{command}`
    raise "FAILED #{command}\n#{result}" if $?.success? == !!options[:fail]
    result
  end

  it "runs tests in parallel" do
    write 'spec/xxx_spec.rb', 'describe("it"){it("should"){puts "TEST1"}}'
    write 'spec/xxx2_spec.rb', 'describe("it"){it("should"){puts "TEST2"}}'
    result = run_tests "spec", :type => 'rspec'

    # test ran and gave their puts
    result.should include('TEST1')
    result.should include('TEST2')

    # all results present
    result.scan('1 example, 0 failure').size.should == 2 # 2 results
    result.scan('2 examples, 0 failures').size.should == 1 # 1 summary
    result.scan(/Finished in \d+\.\d+ seconds/).size.should == 2
    result.scan(/Took \d+\.\d+ seconds/).size.should == 1 # parallel summary
  end

  it "runs tests which outputs accented characters" do
    write "spec/xxx_spec.rb", "#encoding: utf-8\ndescribe('it'){it('should'){puts 'Byłem tu'}}"
    result = run_tests "spec", :type => 'rspec'
    # test ran and gave their puts
    result.should include('Byłem tu')
  end

  it "does not run any tests if there are none" do
    write 'spec/xxx_spec.rb', '1'
    result = run_tests "spec", :type => 'rspec'
    result.should include('No examples found')
    result.should include('Took')
  end

  it "fails when tests fail" do
    write 'spec/xxx_spec.rb', 'describe("it"){it("should"){puts "TEST1"}}'
    write 'spec/xxx2_spec.rb', 'describe("it"){it("should"){1.should == 2}}'
    result = run_tests "spec", :fail => true, :type => 'rspec'

    result.scan('1 example, 1 failure').size.should == 1
    result.scan('1 example, 0 failure').size.should == 1
    result.scan('2 examples, 1 failure').size.should == 1
  end

  it "can serialize stdout" do
    write 'spec/xxx_spec.rb', '5.times{describe("it"){it("should"){sleep 0.01; puts "TEST1"}}}'
    write 'spec/xxx2_spec.rb', 'sleep 0.01; 5.times{describe("it"){it("should"){sleep 0.01; puts "TEST2"}}}'
    result = run_tests "spec", :type => 'rspec', :add => "--serialize-stdout"

    result.should_not =~ /TEST1.*TEST2.*TEST1/m
    result.should_not =~ /TEST2.*TEST1.*TEST2/m
  end

  context "with given commands" do
    it "can exec given commands with ENV['TEST_ENV_NUM']" do
      result = `#{executable} -e 'ruby -e "print ENV[:TEST_ENV_NUMBER.to_s].to_i"' -n 4`
      result.gsub('"','').split('').sort.should == %w[0 2 3 4]
    end

    it "can exec given command non-parallel" do
      result = `#{executable} -e 'ruby -e "sleep(rand(10)/100.0); puts ENV[:TEST_ENV_NUMBER.to_s].inspect"' -n 4 --non-parallel`
      result.split("\n").should == %w["" "2" "3" "4"]
    end

    it "can serialize stdout" do
      result = `#{executable} -e 'ruby -e "5.times{sleep 0.01;puts ENV[:TEST_ENV_NUMBER.to_s].to_i;STDOUT.flush}"' -n 2 --serialize-stdout`
      result.should_not =~ /0.*2.*0/m
      result.should_not =~ /2.*0.*2/m
    end

    it "exists with success if all sub-processes returned success" do
      system("#{executable} -e 'cat /dev/null' -n 4").should == true
    end

    it "exists with failure if any sub-processes returned failure" do
      system("#{executable} -e 'test -e xxxx' -n 4").should == false
    end
  end

  it "runs through parallel_rspec" do
    version = `#{executable} -v`
    `#{bin_folder}/parallel_rspec -v`.should == version
  end

  it "runs through parallel_cucumber" do
    version = `#{executable} -v`
    `#{bin_folder}/parallel_cucumber -v`.should == version
  end

  it "runs through parallel_spinach" do
    version = `#{executable} -v`
    `#{bin_folder}/parallel_spinach -v`.should == version
  end

  it "runs with --group-by found" do
    # it only tests that it does not blow up, as it did before fixing...
    write "spec/x1_spec.rb", "puts '111'"
    run_tests "spec", :type => 'rspec', :add => '--group-by found'
  end

  it "runs faster with more processes" do
    pending if RUBY_PLATFORM == "java"  # just too slow ...
    2.times{|i|
      write "spec/xxx#{i}_spec.rb",  'describe("it"){it("should"){sleep 5}}; $stderr.puts ENV["TEST_ENV_NUMBER"]'
    }
    t = Time.now
    run_tests("spec", :processes => 2, :type => 'rspec')
    expected = 10
    (Time.now - t).should <= expected
  end

  it "can run with given files" do
    write "spec/x1_spec.rb", "puts '111'"
    write "spec/x2_spec.rb", "puts '222'"
    write "spec/x3_spec.rb", "puts '333'"
    result = run_tests "spec/x1_spec.rb spec/x3_spec.rb", :type => 'rspec'
    result.should include('111')
    result.should include('333')
    result.should_not include('222')
  end

  it "runs successfully without any files" do
    results = run_tests "", :type => 'rspec'
    results.should include("2 processes for 0 specs")
    results.should include("Took")
  end

  it "can run with test-options" do
    write "spec/x1_spec.rb", "111"
    write "spec/x2_spec.rb", "111"
    result = run_tests "spec",
      :add => "--test-options ' --version'",
      :processes => 2,
      :type => 'rspec'
    result.should =~ /\d+\.\d+\.\d+.*\d+\.\d+\.\d+/m # prints version twice
  end

  it "runs with PARALLEL_TEST_PROCESSORS processes" do
    processes = 5
    processes.times{|i|
      write "spec/x#{i}_spec.rb", "puts %{ENV-\#{ENV['TEST_ENV_NUMBER']}-}"
    }
    result = run_tests "spec",
      :export => "PARALLEL_TEST_PROCESSORS=#{processes}",
      :processes => processes,
      :type => 'rspec'
    result.scan(/ENV-.?-/).should =~ ["ENV--", "ENV-2-", "ENV-3-", "ENV-4-", "ENV-5-"]
  end

  it "filters test by given pattern and relative paths" do
    write "spec/x_spec.rb", "puts 'XXX'"
    write "spec/y_spec.rb", "puts 'YYY'"
    write "spec/z_spec.rb", "puts 'ZZZ'"
    result = run_tests "spec", :add => "-p '^spec/(x|z)'", :type => "rspec"
    result.should include('XXX')
    result.should_not include('YYY')
    result.should include('ZZZ')
  end

  it "can wait_for_other_processes_to_finish" do
    pending if RUBY_PLATFORM == "java" # just too slow ...
    write "test/a_test.rb", "require 'parallel_tests'; sleep 0.5 ; ParallelTests.wait_for_other_processes_to_finish; puts 'a'"
    write "test/b_test.rb", "sleep 1; puts 'b'"
    write "test/c_test.rb", "sleep 1.5; puts 'c'"
    write "test/d_test.rb", "sleep 2; puts 'd'"
    run_tests("test", :processes => 4).should include("b\nc\nd\na\n")
  end

  it "can run only a single group" do
    pending if RUBY_PLATFORM == "java" # just too slow ...
    write "test/long_test.rb", "puts 'this is a long test'"
    write "test/short_test.rb", "puts 'short test'"

    group_1_result = run_tests("test", :processes => 2, :add => '--only-group 1')
    group_1_result.should include("this is a long test")
    group_1_result.should_not include("short test")

    group_2_result = run_tests("test", :processes => 2, :add => '--only-group 2')
    group_2_result.should_not include("this is a long test")
    group_2_result.should include("short test")
  end

  context "Test::Unit" do
    it "runs" do
      write "test/x1_test.rb", "require 'test/unit'; class XTest < Test::Unit::TestCase; def test_xxx; end; end"
      result = run_tests("test")
      result.should include('1 test')
    end

    it "passes test options" do
      write "test/x1_test.rb", "require 'test/unit'; class XTest < Test::Unit::TestCase; def test_xxx; end; end"
      result = run_tests("test", :add => '--test-options "-v"')
      result.should include('test_xxx') # verbose output of every test
    end

    it "runs successfully without any files" do
      results = run_tests("")
      results.should include("2 processes for 0 tests")
      results.should include("Took")
    end
  end

  context "Cucumber" do
    before do
      write "features/steps/a.rb", "
        Given('I print TEST_ENV_NUMBER'){ puts \"YOUR TEST ENV IS \#{ENV['TEST_ENV_NUMBER']}!\" }
        And('I sleep a bit'){ sleep 0.2 }
        And('I pass'){ true }
        And('I fail'){ fail }
      "
    end

    it "runs tests which outputs accented characters" do
      write "features/good1.feature", "Feature: xxx\n  Scenario: xxx\n    Given I print accented characters"
      write "features/steps/a.rb", "#encoding: utf-8\nGiven('I print accented characters'){ puts \"I tu też\" }"
      result = run_tests "features", :type => "cucumber", :add => '--pattern good'
      result.should include('I tu też')
    end

    it "passes TEST_ENV_NUMBER when running with pattern (issue #86)" do
      write "features/good1.feature", "Feature: xxx\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER"
      write "features/good2.feature", "Feature: xxx\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER"
      write "features/b.feature", "Feature: xxx\n  Scenario: xxx\n    Given I FAIL"
      write "features/steps/a.rb", "Given('I print TEST_ENV_NUMBER'){ puts \"YOUR TEST ENV IS \#{ENV['TEST_ENV_NUMBER']}!\" }"

      result = run_tests "features", :type => "cucumber", :add => '--pattern good'

      result.should include('YOUR TEST ENV IS 2!')
      result.should include('YOUR TEST ENV IS !')
      result.should_not include('I FAIL')
    end

    it "writes a runtime log" do
      log = "tmp/parallel_runtime_cucumber.log"
      write(log, "x")
      2.times{|i|
        # needs sleep so that runtime loggers dont overwrite each other initially
        write "features/good#{i}.feature", "Feature: xxx\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER\n    And I sleep a bit"
      }
      run_tests "features", :type => "cucumber"
      read(log).gsub(/\.\d+/,'').split("\n").should =~ [
        "features/good0.feature:0",
        "features/good1.feature:0"
      ]
    end

    it "runs each feature once when there are more processes then features (issue #89)" do
      2.times{|i|
        write "features/good#{i}.feature", "Feature: xxx\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER"
      }
      result = run_tests "features", :type => "cucumber", :add => '-n 3'
      result.scan(/YOUR TEST ENV IS \d?!/).sort.should == ["YOUR TEST ENV IS !", "YOUR TEST ENV IS 2!"]
    end

    it "runs successfully without any files" do
      results = run_tests("", :type => "cucumber")
      results.should include("2 processes for 0 features")
      results.should include("Took")
    end

    it "collates failing scenarios" do
      write "features/pass.feature", "Feature: xxx\n  Scenario: xxx\n    Given I pass"
      write "features/fail1.feature", "Feature: xxx\n  Scenario: xxx\n    Given I fail"
      write "features/fail2.feature", "Feature: xxx\n  Scenario: xxx\n    Given I fail"
      results = run_tests "features", :processes => 3, :type => "cucumber", :fail => true

      results.should include """
Failing Scenarios:
cucumber features/fail2.feature:2 # Scenario: xxx
cucumber features/fail1.feature:2 # Scenario: xxx

3 scenarios (2 failed, 1 passed)
3 steps (2 failed, 1 passed)
"""
    end

    it "groups by scenario" do
      write "features/long.feature", <<-EOS
      Feature: xxx
        Scenario: xxx
          Given I print TEST_ENV_NUMBER

        Scenario: xxx
          Given I print TEST_ENV_NUMBER

        Scenario Outline: xxx
          Given I print TEST_ENV_NUMBER

        Examples:
          | num |
          | one |
          | two |
      EOS
      result = run_tests "features", :type => "cucumber", :add => "--group-by scenarios"
      result.should include("2 processes for 4 scenarios")
    end

    it "groups by step" do
      write "features/good1.feature", "Feature: xxx\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER"
      write "features/good2.feature", "Feature: xxx\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER"

      result = run_tests "features", :type => "cucumber", :add => '--group-by steps'

      result.should include("2 processes for 2 features")
    end
  end

  context "Spinach", :fails_on_ruby_187 => true do
    before do
      write "features/steps/a.rb", "class A < Spinach::FeatureSteps\n  Given 'I print TEST_ENV_NUMBER' do\n    puts \"YOUR TEST ENV IS \#{ENV['TEST_ENV_NUMBER']}!\"\n  end\n  And 'I sleep a bit' do\n    sleep 0.2\n  end\nend"
    end

    it "runs tests which outputs accented characters" do
      write "features/good1.feature", "Feature: a\n  Scenario: xxx\n    Given I print accented characters"
      write "features/steps/a.rb", "#encoding: utf-8\nclass A < Spinach::FeatureSteps\nGiven 'I print accented characters' do\n  puts \"I tu też\" \n  end\nend"
      result = run_tests "features", :type => "spinach", :add => 'features/good1.feature'#, :add => '--pattern good'
      result.should include('I tu też')
    end

    it "passes TEST_ENV_NUMBER when running with pattern (issue #86)" do
      write "features/good1.feature", "Feature: a\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER"
      write "features/good2.feature", "Feature: a\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER"
      write "features/b.feature", "Feature: b\n  Scenario: xxx\n    Given I FAIL" #Expect this not to be run
      write "features/steps/a.rb", "class A < Spinach::FeatureSteps\nGiven('I print TEST_ENV_NUMBER'){ puts \"YOUR TEST ENV IS \#{ENV['TEST_ENV_NUMBER']}!\" }\nend"

      result = run_tests "features", :type => "spinach", :add => '--pattern good'

      result.should include('YOUR TEST ENV IS 2!')
      result.should include('YOUR TEST ENV IS !')
      result.should_not include('I FAIL')
    end

    it "writes a runtime log" do
      pending 'not yet implemented -- custom runtime logging'
      log = "tmp/parallel_runtime_spinach.log"
      write(log, "x")

      2.times{|i|
        # needs sleep so that runtime loggers dont overwrite each other initially
        write "features/good#{i}.feature", "Feature: A\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER\n    And I sleep a bit"
      }
      result = run_tests "features", :type => "spinach"
      read(log).gsub(/\.\d+/,'').split("\n").should =~ [
        "features/good0.feature:0",
        "features/good1.feature:0"
      ]
    end

    it "runs each feature once when there are more processes then features (issue #89)" do
      2.times{|i|
        write "features/good#{i}.feature", "Feature: A\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER\n"
      }
      result = run_tests "features", :type => "spinach", :add => '-n 3'
      result.scan(/YOUR TEST ENV IS \d?!/).sort.should == ["YOUR TEST ENV IS !", "YOUR TEST ENV IS 2!"]
    end

    it "runs successfully without any files" do
      results = run_tests("", :type => "spinach")
      results.should include("2 processes for 0 features")
      results.should include("Took")
    end
  end
end
