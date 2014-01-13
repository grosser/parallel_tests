require 'open3'

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
          require_list = test_files.map { |filename| %{"#{File.expand_path filename}"} }.join(",")
          cmd = "#{executable} -Itest -e '[#{require_list}].each {|f| require f }' -- #{options[:test_options]}"
          execute_command(cmd, process_number, num_processes, options)
        end

        def line_is_result?(line)
          line.gsub!(/[.F*]/,'')
          line =~ /\d+ failure/
        end

        # --- usually used by other runners

        # finds all tests and partitions them into groups
        def tests_in_groups(tests, num_groups, options={})
          tests = find_tests(tests, options)

          tests = if options[:group_by] == :found
            tests.map { |t| [t, 1] }
          elsif options[:group_by] == :filesize
            with_filesize_info(tests)
          else
            with_runtime_info(tests)
          end
          Grouper.in_even_groups_by_size(tests, num_groups, options)
        end

        def execute_command(cmd, process_number,  num_processes, options)
          env = (options[:env] || {}).merge(
            "TEST_ENV_NUMBER" => test_env_number(process_number),
            "PARALLEL_TEST_GROUPS" => num_processes
          )
          cmd = "nice #{cmd}" if options[:nice]
          execute_command_and_capture_output(env, cmd, options[:serialize_stdout])
        end

        def execute_command_and_capture_output(env, cmd, silence)
          # make processes descriptive / visible in ps -ef
          windows = RbConfig::CONFIG['host_os'] =~ /cygwin|mswin|mingw|bccwin|wince|emx/
          separator = windows ? ' & ' : ';'
          exports = env.map do |k,v|
            if windows
              "(SET \"#{k}=#{v}\")"
            else
              "#{k}=#{v};export #{k}"
            end
          end.join(separator)
          cmd = "#{exports}#{separator}#{cmd}"

          output = open("|#{cmd}", "r") { |output| capture_output(output, silence) }
          exitstatus = $?.exitstatus

          {:stdout => output, :exit_status => exitstatus}
        end

        def find_results(test_output)
          test_output.split("\n").map {|line|
            line.gsub!(/\e\[\d+m/,'')
            next unless line_is_result?(line)
            line
          }.compact
        end

        def test_env_number(process_number)
          process_number == 0 ? '' : process_number + 1
        end

        def summarize_results(results)
          sums = sum_up_results(results)
          sums.sort.map{|word, number|  "#{number} #{word}#{'s' if number != 1}" }.join(', ')
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
        def capture_output(out, silence)
          result = ""
          loop do
            begin
              read = out.readpartial(1000000) # read whatever chunk we can get
              result << read
              unless silence
                $stdout.print read
                $stdout.flush
              end
            end
          end rescue EOFError
          result
        end

        def with_runtime_info(tests)
          lines = File.read(runtime_log).split("\n") rescue []

          # use recorded test runtime if we got enough data
          if lines.size * 1.5 > tests.size
            puts "Using recorded test runtime"
            times = Hash.new(1)
            lines.each do |line|
              test, time = line.split(":")
              next unless test and time
              times[File.expand_path(test)] = time.to_f
            end
            tests.sort.map{|test| [test, times[File.expand_path(test)]] }
          else # use file sizes
            with_filesize_info(tests)
          end
        end

        def with_filesize_info(tests)
          # use filesize to group files
          tests.sort.map { |test| [test, File.stat(test).size] }
        end

        def find_tests(tests, options = {})
          (tests || []).map do |file_or_folder|
            if File.directory?(file_or_folder)
              files = files_in_folder(file_or_folder, options)
              files.grep(test_suffix).grep(options[:pattern]||//)
            else
              file_or_folder
            end
          end.flatten.uniq
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
