require "parallel"
require "parallel_tests/railtie" if defined? Rails::Railtie
require "rbconfig"

module ParallelTests
  WINDOWS = (RbConfig::CONFIG['host_os'] =~ /cygwin|mswin|mingw|bccwin|wince|emx/)
  GREP_PROCESSES_COMMAND = \
  if WINDOWS
    "wmic process get commandline | findstr TEST_ENV_NUMBER | find /c \"TEST_ENV_NUMBER=\" 2>&1"
  else
    "ps -ef | grep [T]EST_ENV_NUMBER= 2>&1"
  end
  RUBY_BINARY = File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name'])

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
        return true if File.exist?(filename)
        current, previous = File.expand_path("..", current), current
      end

      false
    end

    def first_process?
      ENV["TEST_ENV_NUMBER"].to_i <= 1
    end

    def last_process?
      current_process_number = ENV['TEST_ENV_NUMBER']
      total_processes = ENV['PARALLEL_TEST_GROUPS']
      return true if current_process_number.nil? && total_processes.nil?
      current_process_number = '1' if current_process_number.nil?
      current_process_number == total_processes
    end

    def parent_pid
      if WINDOWS
        `wmic process where (processid=#{Process.pid}) get parentprocessid`
      else
        `ps -o ppid= -p#{`ps -o ppid= -p#{Process.pid}`}` #the true parent is one layer up.
      end.to_i
    end

    def with_ruby_binary(command)
      WINDOWS ? "#{RUBY_BINARY} -- #{command}" : command
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

    def delta
      before = now.to_f
      yield
      now.to_f - before
    end
  end
end
