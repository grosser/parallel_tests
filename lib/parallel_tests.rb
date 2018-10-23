require "parallel"
require "parallel_tests/railtie" if defined? Rails::Railtie
require "rbconfig"

module ParallelTests
  WINDOWS = (RbConfig::CONFIG['host_os'] =~ /cygwin|mswin|mingw|bccwin|wince|emx/)
  RUBY_BINARY = File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name'])

  autoload :CLI, "parallel_tests/cli"
  autoload :VERSION, "parallel_tests/version"
  autoload :Grouper, "parallel_tests/grouper"
  autoload :Pids, "parallel_tests/pids"

  class << self
    def determine_number_of_processes(count)
      [
        count,
        ENV["PARALLEL_TEST_PROCESSORS"],
        Parallel.processor_count
      ].detect{|c| not c.to_s.strip.empty? }.to_i
    end

    def with_pid_file
      Tempfile.open('parallel_tests-pidfile') do |f|
        begin
          ENV['PARALLEL_PID_FILE'] = f.path
          # Pids object should be created before threads will start adding pids to it
          # Otherwise we would have to use Mutex to prevent creation of several instances
          @pids = pids
          yield
        ensure
          ENV['PARALLEL_PID_FILE'] = nil
          @pids = nil
        end
      end
    end

    def pids
      @pids ||= Pids.new(pid_file_path)
    end

    def pid_file_path
      ENV.fetch('PARALLEL_PID_FILE')
    end

    def stop_all_processes
      pids.all.each { |pid| Process.kill(:INT, pid) }
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

    def with_ruby_binary(command)
      WINDOWS ? "#{RUBY_BINARY} -- #{command}" : command
    end

    def wait_for_other_processes_to_finish
      return unless ENV["TEST_ENV_NUMBER"]
      sleep 1 until number_of_running_processes <= 1
    end

    def number_of_running_processes
      pids.count
    end

    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def delta
      before = now.to_f
      yield
      now.to_f - before
    end
  end
end
