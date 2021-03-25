# frozen_string_literal: true
require "parallel_tests/test/runner"

module ParallelTests
  module RSpec
    class Runner < ParallelTests::Test::Runner
      DEV_NULL = (WINDOWS ? "NUL" : "/dev/null")
      class << self
        def run_tests(test_files, process_number, num_processes, options)
          exe = executable # expensive, so we cache
          cmd = [exe, options[:test_options], color, spec_opts, *test_files].compact.join(" ")
          execute_command(cmd, process_number, num_processes, options)
        end

        def determine_executable
          if File.exist?("bin/rspec")
            ParallelTests.with_ruby_binary("bin/rspec")
          elsif ParallelTests.bundler_enabled?
            "bundle exec rspec"
          else
            "rspec"
          end
        end

        def runtime_log
          "tmp/parallel_runtime_rspec.log"
        end

        def default_test_folder
          "spec"
        end

        def test_file_name
          "spec"
        end

        def test_suffix
          /_spec\.rb$/
        end

        def line_is_result?(line)
          line =~ /\d+ examples?, \d+ failures?/
        end

        # remove old seed and add new seed
        # --seed 1234
        # --order rand
        # --order rand:1234
        # --order random:1234
        def command_with_seed(cmd, seed)
          clean = cmd.sub(/\s--(seed\s+\d+|order\s+rand(om)?(:\d+)?)\b/, '')
          "#{clean} --seed #{seed}"
        end

        # Summarize results from threads and colorize results based on failure and pending counts.
        #
        def summarize_results(results)
          text = super
          return text unless $stdout.tty?
          sums = sum_up_results(results)
          color =
            if sums['failure'] > 0
              31 # red
            elsif sums['pending'] > 0
              33 # yellow
            else
              32 # green
            end
          "\e[#{color}m#{text}\e[0m"
        end

        private

        # so it can be stubbed....
        def run(cmd)
          `#{cmd}`
        end

        def color
          '--color --tty' if $stdout.tty?
        end

        def spec_opts
          options_file = ['.rspec_parallel', 'spec/parallel_spec.opts', 'spec/spec.opts'].detect { |f| File.file?(f) }
          return unless options_file
          "-O #{options_file}"
        end
      end
    end
  end
end
