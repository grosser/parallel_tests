require "parallel"
require "parallel_tests/railtie" if defined? Rails::Railtie

module ParallelTests
  GREP_PROCESSES_COMMAND = "ps -ef | grep [T]EST_ENV_NUMBER= 2>&1"

  autoload :CLI, "parallel_tests/cli"
  autoload :VERSION, "parallel_tests/version"
  autoload :Grouper, "parallel_tests/grouper"

  class << self
    def determine_number_of_processes(count)
      [
        count,
        ENV["PARALLEL_TEST_PROCESSORS"],
        Parallel.processor_count
      ].detect{|c| not c.to_s.strip.empty? }.to_i
    end

    # copied from http://github.com/carlhuda/bundler Bundler::SharedHelpers#find_gemfile
    def bundler_enabled?
      return true if Object.const_defined?(:Bundler)

      previous = nil
      current = File.expand_path(Dir.pwd)

      until !File.directory?(current) || current == previous
        filename = File.join(current, "Gemfile")
        return true if File.exists?(filename)
        current, previous = File.expand_path("..", current), current
      end

      false
    end

    def first_process?
      !ENV["TEST_ENV_NUMBER"] || ENV["TEST_ENV_NUMBER"].to_i == 0
    end

    def wait_for_other_processes_to_finish
      return unless ENV["TEST_ENV_NUMBER"]
      sleep 1 until number_of_running_processes <= 1
    end

    # Fun fact: this includes the current process if it's run via parallel_tests
    def number_of_running_processes
      result = `#{GREP_PROCESSES_COMMAND}`
      raise "Could not grep for processes -> #{result}" if result.strip != "" && !$?.success?
      result.split("\n").size
    end

    # real time even if someone messed with timecop in tests
    def now
      if Time.respond_to?(:now_without_mock_time) # Timecop
        Time.now_without_mock_time
      else
        Time.now
      end
    end
  end
end
