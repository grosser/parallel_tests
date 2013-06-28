require "parallel_tests/test/runner"
require 'shellwords'

module ParallelTests
  module Cucumber
    class Runner < ParallelTests::Test::Runner
      NAME = 'Cucumber'

      class << self
        def run_tests(test_files, process_number, num_processes, options)
          sanitized_test_files = test_files.map { |val| Shellwords.escape(val) }
          options = options.merge(:env => {"AUTOTEST" => "1"}) if $stdout.tty? # display color when we are in a terminal
          runtime_logging = " --format ParallelTests::Cucumber::RuntimeLogger --out #{runtime_log}"
          cmd = [
            executable,
            (runtime_logging if File.directory?(File.dirname(runtime_log))),
            cucumber_opts(options[:test_options]),
            *sanitized_test_files
          ].compact.join(" ")
          execute_command(cmd, process_number, num_processes, options)
        end

        def determine_executable
          case
          when File.exists?("bin/cucumber")
            "bin/cucumber"
          when ParallelTests.bundler_enabled?
            "bundle exec cucumber"
          when File.file?("script/cucumber")
            "script/cucumber"
          else
            "cucumber"
          end
        end

        def runtime_log
          'tmp/parallel_runtime_cucumber.log'
        end

        def test_file_name
          @test_file_name || "feature"
        end

        def test_suffix
          ".feature"
        end

        def line_is_result?(line)
          line =~ /^\d+ (steps?|scenarios?)/
        end

        # cucumber has 2 result lines per test run, that cannot be added
        # 1 scenario (1 failed)
        # 1 step (1 failed)
        def summarize_results(results)
          sort_order = %w[scenario step failed undefined skipped pending passed]

          %w[scenario step].map do |group|
            group_results = results.grep(/^\d+ #{group}/)
            next if group_results.empty?

            sums = sum_up_results(group_results)
            sums = sums.sort_by { |word, _| sort_order.index(word) || 999 }
            sums.map! do |word, number|
              plural = "s" if word == group and number != 1
              "#{number} #{word}#{plural}"
            end
            "#{sums[0]} (#{sums[1..-1].join(", ")})"
          end.compact.join("\n")
        end

        def cucumber_opts(given)
          if given =~ /--profile/ or given =~ /(^|\s)-p /
            given
          else
            [given, profile_from_config].compact.join(" ")
          end
        end

        def profile_from_config
          # copied from https://github.com/cucumber/cucumber/blob/master/lib/cucumber/cli/profile_loader.rb#L85
          config = Dir.glob('{,.config/,config/}cucumber{.yml,.yaml}').first
          if config && File.read(config) =~ /^parallel:/
            "--profile parallel"
          end
        end

        def tests_in_groups(tests, num_groups, options={})
          @test_file_name = options[:group_by] == :scenario ? "scenario" : "feature"
          if Grouper.respond_to?("by_#{options[:group_by]}".to_sym)
            Grouper.send("by_#{options[:group_by]}".to_sym, find_tests(tests, options), num_groups, options)
          else
            super
          end
        end
      end
    end
  end
end
