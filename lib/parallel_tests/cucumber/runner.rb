require 'parallel_tests/test/runner'

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
        if options[:by_steps] == true
          require 'parallel_tests/gherkin_listener'
          tests = find_tests(tests, options)
          listener = GherkinListener.new
          parser = Gherkin::Parser::Parser.new(listener, true, 'root')
          tests.each{|file|
            parser.parse(File.read(file), file, 0)
          }
          tests = listener.collect.sort_by{|_,value| -value }
          Grouper.by_steps(tests, num_groups)
        else
          super
        end
      end
    end
  end
end
