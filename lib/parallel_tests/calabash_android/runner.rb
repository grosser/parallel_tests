require "parallel_tests/gherkin/runner"

module ParallelTests
  module CalabashAndroid
    class Runner < ParallelTests::Gherkin::Runner
      class << self
        def name
          'calabash-android run /Users/rajdeepverma/work/droid/android/artifacts/automation/FlyDelta-release.apk '
        end

        def run_tests(test_files, process_number, num_processes, options)
          combined_scenarios = test_files

          if options[:group_by] == :scenarios
            grouped = test_files.map { |t| t.split(':') }.group_by(&:first)
            combined_scenarios = grouped.map {|file,files_and_lines| "#{file}:#{files_and_lines.map(&:last).join(':')}" }
          end

          sanitized_test_files = combined_scenarios.map { |val| WINDOWS ? "\"#{val}\"" : Shellwords.escape(val) }

          options[:env] ||= {}
          options[:env] = options[:env].merge({'AUTOTEST' => '1'}) if $stdout.tty? # display color when we are in a terminal

          cmd = [
              executable,
              (runtime_logging if File.directory?(File.dirname(runtime_log))),
              cucumber_opts(options[:test_options]),
              *sanitized_test_files
          ].compact.join(' ')
          cmd = cmd + " ADB_DEVICE_ARG=#{device_for_current_process process_number}"
          execute_command(cmd, process_number, num_processes, options)
        end

        def adb_devices
          `adb devices`.scan(/\n(.*)\t/).flatten
        end

        def device_for_current_process process_num
          adb_devices[process_num]
        end

        def line_is_result?(line)
          super or line =~ failing_scenario_regex
        end

        def summarize_results(results)
          output = []

          failing_scenarios = results.grep(failing_scenario_regex)
          if failing_scenarios.any?
            failing_scenarios.unshift("Failing Scenarios:")
            output << failing_scenarios.join("\n")
          end

          output << super

          output.join("\n\n")
        end

        private

        def failing_scenario_regex
          /^cucumber features\/.+:\d+/
        end
      end
    end
  end
end

