# frozen_string_literal: true
require 'shellwords'
require 'parallel_tests'

module ParallelTests
  module Test
    class Runner
      RuntimeLogTooSmallError = Class.new(StandardError)

      class << self
        # --- usually overwritten by other runners

        def runtime_log
          'tmp/parallel_runtime_test.log'
        end

        def test_suffix
          /_(test|spec).rb$/
        end

        def default_test_folder
          "test"
        end

        def test_file_name
          "test"
        end

        def run_tests(test_files, process_number, num_processes, options)
          require_list = test_files.map { |file| file.gsub(" ", "\\ ") }.join(" ")
          cmd = [
            *executable,
            '-Itest',
            '-e',
            "%w[#{require_list}].each { |f| require %{./\#{f}} }",
            '--',
            *options[:test_options]
          ]
          execute_command(cmd, process_number, num_processes, options)
        end

        # ignores other commands runner noise
        def line_is_result?(line)
          line =~ /\d+ failure(?!:)/
        end

        # --- usually used by other runners

        # finds all tests and partitions them into groups
        def tests_in_groups(tests, num_groups, options = {})
          tests = tests_with_size(tests, options)
          Grouper.in_even_groups_by_size(tests, num_groups, options)
        end

        def tests_with_size(tests, options)
          tests = find_tests(tests, options)

          case options[:group_by]
          when :found
            tests.map! { |t| [t, 1] }
          when :filesize
            sort_by_filesize(tests)
          when :runtime
            sort_by_runtime(
              tests, runtimes(tests, options),
              options.merge(allowed_missing: (options[:allowed_missing_percent] || 50) / 100.0)
            )
          when nil
            # use recorded test runtime if we got enough data
            runtimes = begin
              runtimes(tests, options)
            rescue StandardError
              []
            end
            if runtimes.size * 1.5 > tests.size
              puts "Using recorded test runtime" unless options[:quiet]
              sort_by_runtime(tests, runtimes)
            else
              sort_by_filesize(tests)
            end
          else
            raise ArgumentError, "Unsupported option #{options[:group_by]}"
          end

          tests
        end

        def process_in_batches(cmd, os_cmd_length_limit, tests)
          # Filter elements not starting with value in tests to retain in each batch
          # i.e. retain common parameters for each batch
          retained_elements = cmd.reject { |s| s.start_with?(tests) }
        
          # elements that needs to be checked for length and sliced into batches
          non_retained_elements = cmd.select { |s| s.start_with?(tests) }
        
          batches = []
          index = 0
          while index < non_retained_elements.length
            batch = retained_elements.dup
            total_length = batch.map(&:length).sum
            total_length += batch.size # account for spaces between elements
        
            while index < non_retained_elements.length
              current_element_length = non_retained_elements[index].length
              current_element_length += 1 # account for spaces between elements
        
              # Check if the current element can be added without exceeding the os cmd length limit
              break unless total_length + current_element_length <= os_cmd_length_limit
        
              batch << non_retained_elements[index]
              total_length += current_element_length
              index += 1
            end
        
            batches << batch
          end
        
          batches
        end

        def execute_command(cmd, process_number, num_processes, options)
          number = test_env_number(process_number, options).to_s
          env = (options[:env] || {}).merge(
            "TEST_ENV_NUMBER" => number,
            "PARALLEL_TEST_GROUPS" => num_processes.to_s,
            "PARALLEL_PID_FILE" => ParallelTests.pid_file_path
          )
          cmd = ["nice", *cmd] if options[:nice]

          # being able to run with for example `-output foo-$TEST_ENV_NUMBER` worked originally and is convenient
          cmd = cmd.map { |c| c.gsub("$TEST_ENV_NUMBER", number).gsub("${TEST_ENV_NUMBER}", number) }

          print_command(cmd, env) if report_process_command?(options) && !options[:serialize_stdout]

          result = []
          result = process_in_batches(cmd, 8191, options[:files].first).map do |subcmd|
            result << execute_command_and_capture_output(env, subcmd, options)
          end

          # combine the output of result array into a single Hash
          combined_result = {}
          result.each do |res|
            if combined_result.empty?
              combined_result = res
            else
              combined_result[:stdout] = combined_result[:stdout].to_s + res[:stdout].to_s
              combined_result[:exit_status] = combined_result[:exit_status] + res[:exit_status] # just add
              combined_result[:command] = combined_result[:command] | res[:command]
            end
          end

          combined_result
        end

        def print_command(command, env)
          env_str = ['TEST_ENV_NUMBER', 'PARALLEL_TEST_GROUPS'].map { |e| "#{e}=#{env[e]}" }.join(' ')
          puts [env_str, Shellwords.shelljoin(command)].compact.join(' ')
        end

        def execute_command_and_capture_output(env, cmd, options)
          popen_options = {} # do not add `pgroup: true`, it will break `binding.irb` inside the test
          popen_options[:err] = [:child, :out] if options[:combine_stderr]

          pid = nil
          output = IO.popen(env, cmd, popen_options) do |io|
            pid = io.pid
            ParallelTests.pids.add(pid)
            capture_output(io, env, options)
          end
          ParallelTests.pids.delete(pid) if pid
          exitstatus = $?.exitstatus
          seed = output[/seed (\d+)/, 1]

          output = "#{Shellwords.shelljoin(cmd)}\n#{output}" if report_process_command?(options) && options[:serialize_stdout]

          { env: env, stdout: output, exit_status: exitstatus, command: cmd, seed: seed }
        end

        def find_results(test_output)
          test_output.lines.map do |line|
            line.chomp!
            line.gsub!(/\e\[\d+m/, '') # remove color coding
            next unless line_is_result?(line)
            line
          end.compact
        end

        def test_env_number(process_number, options = {})
          if process_number == 0 && !options[:first_is_1]
            ''
          else
            process_number + 1
          end
        end

        def summarize_results(results)
          sums = sum_up_results(results)
          sums.sort.map { |word, number| "#{number} #{word}#{'s' if number != 1}" }.join(', ')
        end

        # remove old seed and add new seed
        def command_with_seed(cmd, seed)
          clean = remove_command_arguments(cmd, '--seed')
          [*clean, '--seed', seed]
        end

        protected

        def executable
          if (executable = ENV['PARALLEL_TESTS_EXECUTABLE'])
            Shellwords.shellsplit(executable)
          else
            determine_executable
          end
        end

        def determine_executable
          ["ruby"]
        end

        def sum_up_results(results)
          results = results.join(' ').gsub(/s\b/, '') # combine and singularize results
          counts = results.scan(/(\d+) (\w+)/)
          counts.each_with_object(Hash.new(0)) do |(number, word), sum|
            sum[word] += number.to_i
          end
        end

        # read output of the process and print it in chunks
        def capture_output(out, env, options = {})
          result = +""
          begin
            loop do
              read = out.readpartial(1000000) # read whatever chunk we can get
              if Encoding.default_internal
                read = read.force_encoding(Encoding.default_internal)
              end
              result << read
              unless options[:serialize_stdout]
                message = read
                message = "[TEST GROUP #{env['TEST_ENV_NUMBER']}] #{message}" if options[:prefix_output_with_test_env_number]
                $stdout.print message
                $stdout.flush
              end
            end
          rescue EOFError
            nil
          end
          result
        end

        def sort_by_runtime(tests, runtimes, options = {})
          allowed_missing = options[:allowed_missing] || 1.0
          allowed_missing = tests.size * allowed_missing

          # set know runtime for each test
          tests.sort!
          tests.map! do |test|
            allowed_missing -= 1 unless time = runtimes[test]
            if allowed_missing < 0
              log = options[:runtime_log] || runtime_log
              raise RuntimeLogTooSmallError, "Runtime log file '#{log}' does not contain sufficient data to sort #{tests.size} test files, please update or remove it."
            end
            [test, time]
          end

          puts "Runtime found for #{tests.count(&:last)} of #{tests.size} tests" if options[:verbose]

          set_unknown_runtime tests, options
        end

        def runtimes(tests, options)
          log = options[:runtime_log] || runtime_log
          lines = File.read(log).split("\n")
          lines.each_with_object({}) do |line, times|
            test, _, time = line.rpartition(':')
            next unless test && time
            times[test] = time.to_f if tests.include?(test)
          end
        end

        def sort_by_filesize(tests)
          tests.sort!
          tests.map! { |test| [test, File.stat(test).size] }
        end

        def find_tests(tests, options = {})
          suffix_pattern = options[:suffix] || test_suffix
          include_pattern = options[:pattern] || //
          exclude_pattern = options[:exclude_pattern]
          allow_duplicates = options[:allow_duplicates]

          files = (tests || []).flat_map do |file_or_folder|
            if File.directory?(file_or_folder)
              files = files_in_folder(file_or_folder, options)
              files = files.grep(suffix_pattern).grep(include_pattern)
              files -= files.grep(exclude_pattern) if exclude_pattern
              files
            else
              file_or_folder
            end
          end

          allow_duplicates ? files : files.uniq
        end

        def files_in_folder(folder, options = {})
          pattern = if options[:symlinks] == false # not nil or true
            "**/*"
          else
            # follow one symlink and direct children
            # http://stackoverflow.com/questions/357754/can-i-traverse-symlinked-directories-in-ruby-with-a-glob
            "**{,/*/**}/*"
          end
          Dir[File.join(folder, pattern)].uniq.sort
        end

        def remove_command_arguments(command, *args)
          remove_next = false
          command.select do |arg|
            if remove_next
              remove_next = false
              false
            elsif args.include?(arg)
              remove_next = true
              false
            else
              true
            end
          end
        end

        private

        # fill gaps with unknown-runtime if given, average otherwise
        # NOTE: an optimization could be doing runtime by average runtime per file size, but would need file checks
        def set_unknown_runtime(tests, options)
          known, unknown = tests.partition(&:last)
          return if unknown.empty?
          unknown_runtime = options[:unknown_runtime] ||
            (known.empty? ? 1 : known.map!(&:last).sum / known.size) # average
          unknown.each { |set| set[1] = unknown_runtime }
        end

        def report_process_command?(options)
          options[:verbose] || options[:verbose_process_command]
        end
      end
    end
  end
end
