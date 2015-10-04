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

  def self.it_fails_without_any_files(type)
    it "fails without any files" do
      results = run_tests("", fail: true, type: type)
      expect(results).to include("Pass files or folders to run")
    end
  end

  it "runs tests in parallel" do
    write 'spec/xxx_spec.rb', 'describe("it"){it("should"){puts "TEST1"}}'
    write 'spec/xxx2_spec.rb', 'describe("it"){it("should"){puts "TEST2"}}'
    # set processes to false so we verify empty groups are discarded by default
    result = run_tests "spec", :type => 'rspec', :processes => 4

    # test ran and gave their puts
    expect(result).to include('TEST1')
    expect(result).to include('TEST2')

    # all results present
    expect(result.scan('1 example, 0 failure').size).to eq(2) # 2 results
    expect(result.scan('2 examples, 0 failures').size).to eq(1) # 1 summary
    expect(result.scan(/Finished in \d+\.\d+ seconds/).size).to eq(2)
    expect(result.scan(/Took \d+ seconds/).size).to eq(1) # parallel summary

    # verify empty groups are discarded. if retained then it'd say 4 processes for 2 specs
    expect(result).to include '2 processes for 2 specs, ~ 1 specs per process'
  end

  it "runs tests which outputs accented characters" do
    write "spec/xxx_spec.rb", "#encoding: utf-8\ndescribe('it'){it('should'){puts 'Byłem tu'}}"
    result = run_tests "spec", :type => 'rspec'
    # test ran and gave their puts
    expect(result).to include('Byłem tu')
  end

  it "respects default encoding when reading child stdout" do
    write 'test/xxx_test.rb', <<-EOF
      # encoding: utf-8
      require 'test/unit'
      class XTest < Test::Unit::TestCase
        def test_unicode
          raise '¯\\_(ツ)_/¯'
        end
      end
    EOF
    # Need to tell Ruby to default to utf-8 to simulate environments where
    # this is set. (Otherwise, it defaults to nil and the undefined conversion
    # issue doesn't come up.)
    result = run_tests('test', :fail => true,
                       :export => 'RUBYOPT=-Eutf-8:utf-8')
    expect(result).to include('¯\_(ツ)_/¯')
  end

  it "does not run any tests if there are none" do
    write 'spec/xxx_spec.rb', '1'
    result = run_tests "spec", :type => 'rspec'
    expect(result).to include('No examples found')
    expect(result).to include('Took')
  end

  it "shows command with --verbose" do
    write 'spec/xxx_spec.rb', 'describe("it"){it("should"){puts "TEST1"}}'
    write 'spec/xxx2_spec.rb', 'describe("it"){it("should"){1.should == 1}}'
    result = run_tests "spec --verbose", :type => 'rspec'
    expect(result).to include "bundle exec rspec spec/xxx_spec.rb"
    expect(result).to include "bundle exec rspec spec/xxx2_spec.rb"
  end

  it "fails when tests fail" do
    write 'spec/xxx_spec.rb', 'describe("it"){it("should"){puts "TEST1"}}'
    write 'spec/xxx2_spec.rb', 'describe("it"){it("should"){1.should == 2}}'
    result = run_tests "spec", :fail => true, :type => 'rspec'

    expect(result.scan('1 example, 1 failure').size).to eq(1)
    expect(result.scan('1 example, 0 failure').size).to eq(1)
    expect(result.scan('2 examples, 1 failure').size).to eq(1)
  end

  it "can serialize stdout" do
    write 'spec/xxx_spec.rb', '5.times{describe("it"){it("should"){sleep 0.01; puts "TEST1"}}}'
    write 'spec/xxx2_spec.rb', 'sleep 0.01; 5.times{describe("it"){it("should"){sleep 0.01; puts "TEST2"}}}'
    result = run_tests "spec", :type => 'rspec', :add => "--serialize-stdout"

    expect(result).not_to match(/TEST1.*TEST2.*TEST1/m)
    expect(result).not_to match(/TEST2.*TEST1.*TEST2/m)
  end

  it "can serialize stdout and stderr" do
    write 'spec/xxx_spec.rb', '5.times{describe("it"){it("should"){sleep 0.01; $stderr.puts "errTEST1"; puts "TEST1"}}}'
    write 'spec/xxx2_spec.rb', 'sleep 0.01; 5.times{describe("it"){it("should"){sleep 0.01; $stderr.puts "errTEST2"; puts "TEST2"}}}'
    result = run_tests "spec", :type => 'rspec', :add => "--serialize-stdout --combine-stderr"

    expect(result).not_to match(/TEST1.*TEST2.*TEST1/m)
    expect(result).not_to match(/TEST2.*TEST1.*TEST2/m)
  end

  context "with given commands" do
    it "can exec given commands with ENV['TEST_ENV_NUMBER']" do
      result = `#{executable} -e 'ruby -e "print ENV[:TEST_ENV_NUMBER.to_s].to_i"' -n 4`
      expect(result.gsub('"','').split('').sort).to eq(%w[0 2 3 4])
    end

    it "can exec given command non-parallel" do
      result = `#{executable} -e 'ruby -e "sleep(rand(10)/100.0); puts ENV[:TEST_ENV_NUMBER.to_s].inspect"' -n 4 --non-parallel`
      expect(result.split("\n")).to eq(%w["" "2" "3" "4"])
    end

    it "can serialize stdout" do
      result = `#{executable} -e 'ruby -e "5.times{sleep 0.01;puts ENV[:TEST_ENV_NUMBER.to_s].to_i;STDOUT.flush}"' -n 2 --serialize-stdout`
      expect(result).not_to match(/0.*2.*0/m)
      expect(result).not_to match(/2.*0.*2/m)
    end

    it "exists with success if all sub-processes returned success" do
      expect(system("#{executable} -e 'cat /dev/null' -n 4")).to eq(true)
    end

    it "exists with failure if any sub-processes returned failure" do
      expect(system("#{executable} -e 'test -e xxxx' -n 4")).to eq(false)
    end
  end

  it "runs through parallel_rspec" do
    version = `#{executable} -v`
    expect(`#{bin_folder}/parallel_rspec -v`).to eq(version)
  end

  it "runs through parallel_cucumber" do
    version = `#{executable} -v`
    expect(`#{bin_folder}/parallel_cucumber -v`).to eq(version)
  end

  it "runs through parallel_spinach" do
    version = `#{executable} -v`
    expect(`#{bin_folder}/parallel_spinach -v`).to eq(version)
  end

  it "runs with --group-by found" do
    # it only tests that it does not blow up, as it did before fixing...
    write "spec/x1_spec.rb", "puts '111'"
    run_tests "spec", :type => 'rspec', :add => '--group-by found'
  end

  it "runs in parallel" do
    2.times do |i|
      write "spec/xxx#{i}_spec.rb", 'describe("it") { it("should"){ puts "START"; sleep 1; puts "END" } }'
    end
    result = run_tests("spec", processes: 2, type: 'rspec')
    expect(result.scan(/START|END/)).to eq(["START", "START", "END", "END"])
  end

  it "runs with files that have spaces" do
    write "test/xxx _test.rb", 'puts "YES"'
    result = run_tests("test", processes: 2, type: 'test')
    expect(result).to include "YES"
  end

  it "uses relative paths for easy copying" do
    write "test/xxx_test.rb", 'puts "YES"'
    result = run_tests("test", processes: 2, type: 'test', add: '--verbose')
    expect(result).to include "YES"
    expect(result).to include "[test/xxx_test.rb]"
    expect(result).not_to include Dir.pwd
  end

  it "can run with given files" do
    write "spec/x1_spec.rb", "puts '111'"
    write "spec/x2_spec.rb", "puts '222'"
    write "spec/x3_spec.rb", "puts '333'"
    result = run_tests "spec/x1_spec.rb spec/x3_spec.rb", :type => 'rspec'
    expect(result).to include('111')
    expect(result).to include('333')
    expect(result).not_to include('222')
  end

  it "can run with test-options" do
    write "spec/x1_spec.rb", "111"
    write "spec/x2_spec.rb", "111"
    result = run_tests "spec",
      :add => "--test-options ' --version'",
      :processes => 2,
      :type => 'rspec'
    expect(result).to match(/\d+\.\d+\.\d+.*\d+\.\d+\.\d+/m) # prints version twice
  end

  it "runs with PARALLEL_TEST_PROCESSORS processes" do
    skip if RUBY_PLATFORM == "java" # execution expired issue on JRuby
    processes = 5
    processes.times{|i|
      write "spec/x#{i}_spec.rb", "puts %{ENV-\#{ENV['TEST_ENV_NUMBER']}-}"
    }
    result = run_tests "spec",
      :export => "PARALLEL_TEST_PROCESSORS=#{processes}",
      :processes => processes,
      :type => 'rspec'
    expect(result.scan(/ENV-.?-/)).to match_array(["ENV--", "ENV-2-", "ENV-3-", "ENV-4-", "ENV-5-"])
  end

  it "filters test by given pattern and relative paths" do
    write "spec/x_spec.rb", "puts 'XXX'"
    write "spec/y_spec.rb", "puts 'YYY'"
    write "spec/z_spec.rb", "puts 'ZZZ'"
    result = run_tests "spec", :add => "-p '^spec/(x|z)'", :type => "rspec"
    expect(result).to include('XXX')
    expect(result).not_to include('YYY')
    expect(result).to include('ZZZ')
  end

  it "can wait_for_other_processes_to_finish" do
    skip if RUBY_PLATFORM == "java" # just too slow ...
    write "test/a_test.rb", "require 'parallel_tests'; sleep 0.5 ; ParallelTests.wait_for_other_processes_to_finish; puts 'a'"
    write "test/b_test.rb", "sleep 1; puts 'b'"
    write "test/c_test.rb", "sleep 1.5; puts 'c'"
    write "test/d_test.rb", "sleep 2; puts 'd'"
    expect(run_tests("test", :processes => 4)).to include("b\nc\nd\na\n")
  end

  it "can run only a single group" do
    skip if RUBY_PLATFORM == "java" # just too slow ...
    write "test/long_test.rb", "puts 'this is a long test'"
    write "test/short_test.rb", "puts 'short test'"

    group_1_result = run_tests("test", :processes => 2, :add => '--only-group 1')
    expect(group_1_result).to include("this is a long test")
    expect(group_1_result).not_to include("short test")

    group_2_result = run_tests("test", :processes => 2, :add => '--only-group 2')
    expect(group_2_result).not_to include("this is a long test")
    expect(group_2_result).to include("short test")
  end

  context "RSpec" do
    it_fails_without_any_files "rspec"

    it "captures seed with random failures" do
      write 'spec/xxx_spec.rb', 'describe("it"){it("should"){puts "TEST1"}}'
      write 'spec/xxx2_spec.rb', 'describe("it"){it("should"){1.should == 2}}'
      result = run_tests "spec", :add => "--test-options '--seed 1234'", :fail => true, :type => 'rspec'
      expect(result).to include("Randomized with seed 1234")
      expect(result).to include("bundle exec rspec spec/xxx2_spec.rb --seed 1234")
    end
  end

  context "Test::Unit" do
    it "runs" do
      write "test/x1_test.rb", "require 'test/unit'; class XTest < Test::Unit::TestCase; def test_xxx; end; end"
      result = run_tests("test")
      expect(result).to include('1 test')
    end

    it "passes test options" do
      write "test/x1_test.rb", "require 'test/unit'; class XTest < Test::Unit::TestCase; def test_xxx; end; end"
      result = run_tests("test", :add => '--test-options "-v"')
      expect(result).to include('test_xxx') # verbose output of every test
    end

    it_fails_without_any_files "test"
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
      expect(result).to include('I tu też')
    end

    it "passes TEST_ENV_NUMBER when running with pattern (issue #86)" do
      write "features/good1.feature", "Feature: xxx\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER"
      write "features/good2.feature", "Feature: xxx\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER"
      write "features/b.feature", "Feature: xxx\n  Scenario: xxx\n    Given I FAIL"
      write "features/steps/a.rb", "Given('I print TEST_ENV_NUMBER'){ puts \"YOUR TEST ENV IS \#{ENV['TEST_ENV_NUMBER']}!\" }"

      result = run_tests "features", :type => "cucumber", :add => '--pattern good'

      expect(result).to include('YOUR TEST ENV IS 2!')
      expect(result).to include('YOUR TEST ENV IS !')
      expect(result).not_to include('I FAIL')
    end

    it "writes a runtime log" do
      skip "TODO find out why this fails" if RUBY_PLATFORM == "java"

      log = "tmp/parallel_runtime_cucumber.log"
      write(log, "x")
      2.times{|i|
        # needs sleep so that runtime loggers dont overwrite each other initially
        write "features/good#{i}.feature", "Feature: xxx\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER\n    And I sleep a bit"
      }
      run_tests "features", :type => "cucumber"
      expect(read(log).gsub(/\.\d+/,'').split("\n")).to match_array([
        "features/good0.feature:0",
        "features/good1.feature:0"
      ])
    end

    it "runs each feature once when there are more processes then features (issue #89)" do
      2.times{|i|
        write "features/good#{i}.feature", "Feature: xxx\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER"
      }
      result = run_tests "features", :type => "cucumber", :add => '-n 3'
      expect(result.scan(/YOUR TEST ENV IS \d?!/).sort).to eq(["YOUR TEST ENV IS !", "YOUR TEST ENV IS 2!"])
    end

    it_fails_without_any_files "cucumber"

    it "collates failing scenarios" do
      write "features/pass.feature", "Feature: xxx\n  Scenario: xxx\n    Given I pass"
      write "features/fail1.feature", "Feature: xxx\n  Scenario: xxx\n    Given I fail"
      write "features/fail2.feature", "Feature: xxx\n  Scenario: xxx\n    Given I fail"
      results = run_tests "features", :processes => 3, :type => "cucumber", :fail => true

      expect(results).to include """
Failing Scenarios:
cucumber features/fail2.feature:2 # Scenario: xxx
cucumber features/fail1.feature:2 # Scenario: xxx

3 scenarios (2 failed, 1 passed)
3 steps (2 failed, 1 passed)
"""
    end

    it "groups by scenario" do
      skip "ScenarioLineLogger not supported anymore after upgrading to Cucumber 2.0, please fix!"
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
      expect(result).to include("2 processes for 4 scenarios")
    end

    it "groups by step" do
      write "features/good1.feature", "Feature: xxx\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER"
      write "features/good2.feature", "Feature: xxx\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER"

      result = run_tests "features", :type => "cucumber", :add => '--group-by steps'

      expect(result).to include("2 processes for 2 features")
    end

    it "captures seed with random failures" do
      write "features/good1.feature", "Feature: xxx\n  Scenario: xxx\n    Given I fail"
      result = run_tests "features", :type => "cucumber", :add => '--test-options "--order random:1234"', :fail => true
      expect(result).to include("Randomized with seed 1234")
      expect(result).to include("bundle exec cucumber features/good1.feature --order random:1234")
    end
  end

  context "Spinach" do
    before do
      write "features/steps/a.rb", "class A < Spinach::FeatureSteps\n  Given 'I print TEST_ENV_NUMBER' do\n    puts \"YOUR TEST ENV IS \#{ENV['TEST_ENV_NUMBER']}!\"\n  end\n  And 'I sleep a bit' do\n    sleep 0.2\n  end\nend"
    end

    it "runs tests which outputs accented characters" do
      write "features/good1.feature", "Feature: a\n  Scenario: xxx\n    Given I print accented characters"
      write "features/steps/a.rb", "#encoding: utf-8\nclass A < Spinach::FeatureSteps\nGiven 'I print accented characters' do\n  puts \"I tu też\" \n  end\nend"
      result = run_tests "features", :type => "spinach", :add => 'features/good1.feature'#, :add => '--pattern good'
      expect(result).to include('I tu też')
    end

    it "passes TEST_ENV_NUMBER when running with pattern (issue #86)" do
      write "features/good1.feature", "Feature: a\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER"
      write "features/good2.feature", "Feature: a\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER"
      write "features/b.feature", "Feature: b\n  Scenario: xxx\n    Given I FAIL" #Expect this not to be run
      write "features/steps/a.rb", "class A < Spinach::FeatureSteps\nGiven('I print TEST_ENV_NUMBER'){ puts \"YOUR TEST ENV IS \#{ENV['TEST_ENV_NUMBER']}!\" }\nend"

      result = run_tests "features", :type => "spinach", :add => '--pattern good'

      expect(result).to include('YOUR TEST ENV IS 2!')
      expect(result).to include('YOUR TEST ENV IS !')
      expect(result).not_to include('I FAIL')
    end

    it "writes a runtime log" do
      skip 'not yet implemented -- custom runtime logging'
      log = "tmp/parallel_runtime_spinach.log"
      write(log, "x")

      2.times{|i|
        # needs sleep so that runtime loggers dont overwrite each other initially
        write "features/good#{i}.feature", "Feature: A\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER\n    And I sleep a bit"
      }
      result = run_tests "features", :type => "spinach"
      expect(read(log).gsub(/\.\d+/,'').split("\n")).to match_array([
        "features/good0.feature:0",
        "features/good1.feature:0"
      ])
    end

    it "runs each feature once when there are more processes then features (issue #89)" do
      2.times{|i|
        write "features/good#{i}.feature", "Feature: A\n  Scenario: xxx\n    Given I print TEST_ENV_NUMBER\n"
      }
      result = run_tests "features", :type => "spinach", :add => '-n 3'
      expect(result.scan(/YOUR TEST ENV IS \d?!/).sort).to eq(["YOUR TEST ENV IS !", "YOUR TEST ENV IS 2!"])
    end

    it_fails_without_any_files "spinach"
  end
end
