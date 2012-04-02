require 'parallel_tests/test/runner'

module ParallelTests
  module Cucumber
    class Runner < ParallelTests::Test::Runner
      def self.run_tests(test_files, process_number, options)
        color = ($stdout.tty? ? 'AUTOTEST=1 ; export AUTOTEST ;' : '')#display color when we are in a terminal
        runtime_logging = " --format ParallelTests::Cucumber::RuntimeLogger --out #{runtime_log}"
        options[:test_options] = options[:test_options].nil? ? cucumber_opts : "#{options[:test_options]} #{cucumber_opts}".strip
        cmd = "#{color} #{executable}"
        cmd << runtime_logging if File.directory?(File.dirname(runtime_log))
        cmd << " #{options[:test_options]} #{test_files*' '}"
        execute_command(cmd, process_number, options)
      end

      def self.executable
        if ParallelTests.bundler_enabled?
          "bundle exec cucumber"
        elsif File.file?("script/cucumber")
          "script/cucumber"
        else
          "cucumber"
        end
      end

      def self.runtime_log
        'tmp/parallel_runtime_cucumber.log'
      end

      def self.test_file_name
        "feature"
      end

      def self.test_suffix
        ".feature"
      end

      def self.line_is_result?(line)
        line =~ /^\d+ (steps|scenarios)/
      end

      def self.cucumber_opts
        if File.exists?('.cucumber_parallel')
          File.read('.cucumber_parallel').strip
        else
          ''
        end
      end
    end
  end
end
