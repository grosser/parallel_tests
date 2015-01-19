require 'open3'
require 'yaml'

ROOT_DIR = File.expand_path('.')


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
          Pathname.new(ENV['BUILD_REPORTS'] || '.') + '..' + 'rails_3_test_stats.yml'
        end

        def local_runtime_log
          Pathname.new(ENV['BUILD_REPORTS'] || '.') + 'rails_3_test_stats.yml'
        end

        def test_suffix
          /_(test|spec).rb$/
        end

        def test_file_name
          "test"
        end

        def run_tests(test_files, process_number, num_processes, options)
          require_list = ([File.expand_path('../test_unit_filename', __FILE__)] + test_files).map { |filename| %<"#{File.expand_path filename}"> }.join(",")
          cmd = "#{executable} -Itest -e 'ROOT_DIR=\"#{ROOT_DIR}\"; [#{require_list}].each {|f| require f }' -- #{options[:test_options]}"
          execute_command_and_capture_output({}, cmd, process_number, num_processes)
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
          else
            with_runtime_info(tests)
          end
          Grouper.in_even_groups_by_size(tests, num_groups, options)
        end

        # executes command without redirecting stdout and stderr.
        # returns exitstatus
        def execute_command(cmd, process_number, num_processes, options)
          env = options[:env] || {}
          cmd = "nice #{cmd}" if options[:nice]
          result = execute_command_and_capture_output(env, cmd, process_number, num_processes)
          if result[:exit_status].nonzero?
            $stdout.write(result[:stdout])
          end
          result[:exit_status]
        end

        # executes command and returns stdout and stderr combined in a hash with keys :stdout, :summary_lines, :deferred_tests, and :exit_status
        def execute_command_and_capture_output(initial_env, plain_cmd, process_number, num_processes)
          env = initial_env.merge(
            "TEST_ENV_NUMBER"       => test_env_number(process_number),
            "PARALLEL_TEST_GROUPS"  => num_processes
          )
          # make processes descriptive / visible in ps -ef
          windows = RbConfig::CONFIG['host_os'] =~ /cygwin|mswin|mingw|bccwin|wince|emx/
          separator = windows ? ' & ' : ';'
          exports = env.map do |k,v|
            if windows
              "(SET \"#{k}=#{v}\")"
            else
              "#{k}=#{v};export #{k}"
            end
          end
          cmd = (exports + [plain_cmd]).join(separator)

          output_dir = Pathname.new(ENV['BUILD_REPORTS'] || 'tmp')
          output_file = output_dir + "#{test_env_number(process_number)}.out"
          FileUtils.mkdir_p(output_dir)

          puts("Running: #{cmd} >> #{output_file} 2>&1") unless ENV['VERBOSE'] == 'false'

          system("#{cmd} > #{output_file} 2>&1")
          output = File.read(output_file)
          puts output unless ENV['VERBOSE'] == 'false'

          cleaned_output = output.gsub(/\ALoaded.*\nStarted\n/, '').gsub(/\n\n\n+/m, "\n\n")
          deferred_tests, other_lines = cleaned_output.split("\n").partition { |line| line =~ /\A  \* DEFERRED: / }
          found_summary = false
          summary_lines, test_result_lines = other_lines.partition { |line| found_summary ||= line =~ /\AFinished in \d+ second/i }
          {:stdout => test_result_lines*"\n", :summary_lines => summary_lines, :deferred_tests => deferred_tests, :exit_status => $?.exitstatus}
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
          stats =
            begin
              YAML.load_file(runtime_log)
            rescue => ex
              puts "Exception loading stats:\n#{ex}"
              {}
            end

          filename_warning = " [from file #{runtime_log}]"

          # use recorded test runtime if we got enough data
          if stats.size * 1.5 > tests.size
            puts "Using recorded test runtime"# unless ENV['VERBOSE'] == 'false'
            tests.sort.map do |test|
              file_stats = stats[test]
              seconds =
                if file_stats
                  _seconds = file_stats['_seconds']
                  if !_seconds.nil? && seconds != ''
                    _seconds.to_f
                  else
                    STDERR.puts "Missing _seconds for #{test}: #{file_stats.inspect}#{filename_warning}"
                    filename_warning = nil
                    10.0
                  end
                else
                  STDERR.puts "Guessing run time of 10 seconds for #{test}#{filename_warning}"# unless ENV['VERBOSE'] == 'false'
                  filename_warning = nil
                  10.0
                end
              [test, seconds]
            end
          else # use file sizes
            puts "Using test file size in bytes#{filename_warning}"# unless ENV['VERBOSE'] == 'false'
            tests.sort.map{|test| [test, File.stat(test).size] }
          end
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
