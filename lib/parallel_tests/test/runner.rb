require 'parallel_tests'

module ParallelTests
  module Test
    class Runner
      NAME = 'Test'

      class << self
        # --- usually overwritten by other runners

        def name
          NAME
        end

        def runtime_log
          'tmp/parallel_runtime_test.log'
        end

        def test_suffix
          /_(test|spec).rb$/
        end

        def test_file_name
          "test"
        end

        def run_tests(test_files, process_number, num_processes, options)
          require_list = test_files.map { |file| file.sub(" ", "\\ ") }.join(" ")
          cmd = "#{executable} -Itest -e '%w[#{require_list}].each { |f| require %{./\#{f}} }' -- #{options[:test_options]}"
          execute_command(cmd, process_number, num_processes, options)
        end

        # ignores other commands runner noise
        def line_is_result?(line)
          line =~ /\d+ failure(?!:)/
        end

        # --- usually used by other runners

        # finds all tests and partitions them into groups
        def tests_in_groups(tests, num_groups, options={})
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
            sort_by_runtime(tests, runtimes(tests, options), options.merge(allowed_missing: (options[:allowed_missing_percent] || 50) / 100.0))
          when nil
            # use recorded test runtime if we got enough data
            runtimes = runtimes(tests, options) rescue []
            if runtimes.size * 1.5 > tests.size
              puts "Using recorded test runtime"
              sort_by_runtime(tests, runtimes)
            else
              sort_by_filesize(tests)
            end
          else
            raise ArgumentError, "Unsupported option #{options[:group_by]}"
          end

          tests
        end

        def execute_command(cmd, process_number, num_processes, options)
          env = (options[:env] || {}).merge(
            "TEST_ENV_NUMBER" => test_env_number(process_number, options).to_s,
            "PARALLEL_TEST_GROUPS" => num_processes.to_s,
            "PARALLEL_PID_FILE" => ParallelTests.pid_file_path,
          )
          cmd = "nice #{cmd}" if options[:nice]
          cmd = "#{cmd} 2>&1" if options[:combine_stderr]

          puts cmd if options[:verbose] && !options[:serialize_stdout]

          execute_command_and_capture_output(env, cmd, options)
        end

        def execute_command_and_capture_output(env, cmd, options)
          pid = nil
          output = IO.popen(env, cmd) do |io|
            pid = io.pid
            ParallelTests.pids.add(pid)
            capture_output(io, env, options)
          end
          ParallelTests.pids.delete(pid) if pid
          exitstatus = $?.exitstatus
          seed = output[/seed (\d+)/,1]

          output = [cmd, output].join("\n") if options[:verbose] && options[:serialize_stdout]

          {:stdout => output, :exit_status => exitstatus, :command => cmd, :seed => seed}
        end

        def find_results(test_output)
          test_output.lines.map do |line|
            line.chomp!
            line.gsub!(/\e\[\d+m/, '') # remove color coding
            next unless line_is_result?(line)
            line
          end.compact
        end

        def test_env_number(process_number, options={})
          if process_number == 0 && !options[:first_is_1]
            ''
          else
            process_number + 1
          end
        end

        def summarize_results(results)
          sums = sum_up_results(results)
          sums.sort.map{|word, number|  "#{number} #{word}#{'s' if number != 1}" }.join(', ')
        end

        # remove old seed and add new seed
        def command_with_seed(cmd, seed)
          clean = cmd.sub(/\s--seed\s+\d+\b/, '')
          "#{clean} --seed #{seed}"
        end

        protected

        def executable
          ENV['PARALLEL_TESTS_EXECUTABLE'] || determine_executable
        end

        def determine_executable
          "ruby"
        end

        def sum_up_results(results)
          results = results.join(' ').gsub(/s\b/,'') # combine and singularize results
          counts = results.scan(/(\d+) (\w+)/)
          counts.inject(Hash.new(0)) do |sum, (number, word)|
            sum[word] += number.to_i
            sum
          end
        end

        # read output of the process and print it in chunks
        def capture_output(out, env, options={})
          result = ""
          loop do
            begin
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
          end rescue EOFError
          result
        end

        def sort_by_runtime(tests, runtimes, options={})
          allowed_missing = options[:allowed_missing] || 1.0
          allowed_missing = tests.size * allowed_missing

          # set know runtime for each test
          tests.sort!
          tests.map! do |test|
            allowed_missing -= 1 unless time = runtimes[test]
            if allowed_missing < 0
              log = options[:runtime_log] || runtime_log
              raise "Runtime log file '#{log}' does not contain sufficient data to sort #{tests.size} test files, please update it."
            end
            [test, time]
          end

          if options[:verbose]
            puts "Runtime found for #{tests.count(&:last)} of #{tests.size} tests"
          end

          # fill gaps with unknown-runtime if given, average otherwise
          known, unknown = tests.partition(&:last)
          average = (known.any? ? known.map!(&:last).inject(:+) / known.size : 1)
          unknown_runtime = options[:unknown_runtime] || average
          unknown.each { |set| set[1] = unknown_runtime }
        end

        def runtimes(tests, options)
          log = options[:runtime_log] || runtime_log
          lines = File.read(log).split("\n")
          lines.each_with_object({}) do |line, times|
            test, _, time = line.rpartition(':')
            next unless test and time
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

          (tests || []).flat_map do |file_or_folder|
            if File.directory?(file_or_folder)
              files = files_in_folder(file_or_folder, options)
              files = files.grep(suffix_pattern).grep(include_pattern)
              files -= files.grep(exclude_pattern) if exclude_pattern
              files
            else
              file_or_folder
            end
          end.uniq
        end

        def files_in_folder(folder, options={})
          pattern = if options[:symlinks] == false # not nil or true
            "**/*"
          else
            # follow one symlink and direct children
            # http://stackoverflow.com/questions/357754/can-i-traverse-symlinked-directories-in-ruby-with-a-glob
            "**{,/*/**}/*"
          end
          Dir[File.join(folder, pattern)].uniq
        end
      end
    end
  end
end
