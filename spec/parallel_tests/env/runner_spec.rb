require "spec_helper"
require "parallel_tests/env/runner"

describe ParallelTests::Env::Runner do
  test_tests_in_groups(ParallelTests::Env::Runner, 'test', '_spec.rb')

  describe ".find_tests" do
    def call(*args)
      ParallelTests::Env::Runner.send(:find_tests, *args)
    end

    def with_files(files)
      begin
        root = "/tmp/test-find_tests-#{rand(999)}"
        `mkdir #{root}`
        files.each do |file|
          parent = "#{root}/#{File.dirname(file)}"
          `mkdir -p #{parent}` unless File.exist?(parent)
          `touch #{root}/#{file}`
        end
        yield root
      ensure
        `rm -rf #{root}`
      end
    end

    def inside_dir(dir)
      old = Dir.pwd
      Dir.chdir dir
      yield
    ensure
      Dir.chdir old
    end

    it "finds test in folders with appended /" do
      with_files(['b/a_spec.rb']) do |root|
        call(["#{root}/"]).sort.should == [
          "#{root}/b/a_spec.rb",
        ]
      end
    end

  end
end
