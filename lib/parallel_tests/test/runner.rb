require 'open3'

module ParallelTests
  module Test
    class Runner
      NAME = 'Test'

      # --- usually overwritten by other runners

      def self.name
        NAME
      end

      def self.runtime_log
        'tmp/parallel_runtime_test.log'
      end

      def self.test_suffix
        "_test.rb"
      end

      def self.test_file_name
        "test"
      end

      def self.run_tests(test_files, process_number, num_processes, options)
        require_list = test_files.map { |filename| %{"#{File.expand_path filename}"} }.join(",")
        cmd = "#{executable} -Itest -e '[#{require_list}].each {|f| require f }' -- #{options[:test_options]}"
        execute_command(cmd, process_number, num_processes, options)
      end

      def self.line_is_result?(line)
        line =~ /\d+ failure/
      end

      # --- usually used by other runners

      # finds all tests and partitions them into groups
      def self.tests_in_groups(tests, num_groups, options={})
        tests = find_tests(tests, options)

        tests = if options[:group_by] == :found
          tests.map { |t| [t, 1] }
        else
          with_runtime_info(tests)
        end
        Grouper.in_even_groups_by_size(tests, num_groups, options)
      end

      def self.execute_command(cmd, process_number,  num_processes, options)
        env = (options[:env] || {}).merge(
          "TEST_ENV_NUMBER" => test_env_number(process_number),
          "PARALLEL_TEST_GROUPS" => num_processes
        )
        cmd = "nice #{cmd}" if options[:nice]
        execute_command_and_capture_output(env, cmd, options[:serialize_stdout])
      end

      def self.execute_command_and_capture_output(env, cmd, silence)
        # make processes descriptive / visible in ps -ef
        exports = env.map do |k,v|
          "#{k}=#{v};export #{k}"
        end.join(";")
        cmd = "#{exports};#{cmd}"

        output, errput, exitstatus = nil
        if RUBY_VERSION =~ /^1\.8/
          open("|#{cmd}", "r") do |output|
            output, errput = capture_output(output, nil, silence)
          end
          exitstatus = $?.exitstatus
        else
          Open3.popen3(cmd) do |stdin, stdout, stderr, thread|
            stdin.close
            output, errput = capture_output(stdout, stderr, silence)
            exitstatus = thread.value.exitstatus
          end
        end

        {:stdout => output, :stderr => errput, :exit_status => exitstatus}
      end

      def self.find_results(test_output)
        test_output.split("\n").map {|line|
          line = line.gsub(/\.|F|\*/,'').gsub(/\e\[\d+m/,'')
          next unless line_is_result?(line)
          line
        }.compact
      end

      def self.test_env_number(process_number)
        process_number == 0 ? '' : process_number + 1
      end

      def self.summarize_results(results)
        sums = sum_up_results(results)
        sums.sort.map{|word, number|  "#{number} #{word}#{'s' if number != 1}" }.join(', ')
      end

      protected

      def self.executable
        ENV['PARALLEL_TESTS_EXECUTABLE'] || determine_executable
      end

      def self.determine_executable
        "ruby"
      end

      def self.sum_up_results(results)
        results = results.join(' ').gsub(/s\b/,'') # combine and singularize results
        counts = results.scan(/(\d+) (\w+)/)
        counts.inject(Hash.new(0)) do |sum, (number, word)|
          sum[word] += number.to_i
          sum
        end
      end

      # read output of the process and print it in chunks
      def self.capture_output(out, err, silence)
        results = ["", ""]
        loop do
          [[out, $stdout, 0], [err, $stderr, 1]].each do |input, output, index|
            next unless input
            begin
              read = input.readpartial(1000000) # read whatever chunk we can get
              results[index] << read
              if index == 1 || !silence
                output.print read
                output.flush
              end
            rescue EOFError
              raise if index == 0 # we only care about the end of stdout
            end
          end
        end rescue EOFError
        results
      end

      def self.with_runtime_info(tests)
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
          tests.sort.map{|test| [test, File.stat(test).size] }
        end
      end

      def self.find_tests(tests, options = {})
        (tests || []).map do |file_or_folder|
          if File.directory?(file_or_folder)
            files = files_in_folder(file_or_folder, options)
            files.grep(/#{Regexp.escape test_suffix}$/).grep(options[:pattern]||//)
          else
            file_or_folder
          end
        end.flatten.uniq
      end

      def self.files_in_folder(folder, options={})
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
