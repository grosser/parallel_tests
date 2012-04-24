require 'parallel_tests/test/runner'
require 'json'
module ParallelTests
  module Cucumber
    class Runner < ParallelTests::Test::Runner
      def self.run_tests(test_files, process_number, options)
        color = ($stdout.tty? ? 'AUTOTEST=1 ; export AUTOTEST ;' : '')#display color when we are in a terminal
        runtime_logging = " --format ParallelTests::Cucumber::RuntimeLogger --out #{runtime_log}"
        cmd = [
          color,
          executable,
          (runtime_logging if File.directory?(File.dirname(runtime_log))),
          options[:test_options],
          cucumber_opts,
          *test_files
        ].compact.join(" ")
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
        config = 'config/cucumber.yml'
        if File.exists?(config) && File.read(config) =~ /^parallel:/
          "--profile parallel"
        end
      end

      def self.tests_in_groups(tests, num_groups, options={})
        tests = find_tests(tests, options)
        if options[:by_steps] == true
          Grouper.by_steps(tests, num_groups, Listener.new)
        elsif options[:no_sort] == true
            Grouper.in_groups(tests, num_groups)
        else
          tests = with_runtime_info(tests)
          Grouper.in_even_groups_by_size(tests, num_groups, options)
        end
      end

    end
  end
end
