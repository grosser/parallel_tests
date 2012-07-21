module ParallelTests
  module Test
    class Runner
      # --- usually overwritten by other runners

      def self.runtime_log
        'tmp/parallel_runtime_test.log'
      end

      def self.test_suffix
        "_test.rb"
      end

      def self.test_file_name
        "test"
      end

      def self.run_tests(test_files, process_number, options)
        require_list = test_files.map { |filename| %{"#{File.expand_path filename}"} }.join(",")
        cmd = "ruby -Itest -e '[#{require_list}].each {|f| require f }' -- #{options[:test_options]}"
        execute_command(cmd, process_number, options)
      end

      def self.line_is_result?(line)
        line =~ /\d+ failure/
      end

      # --- usually used by other runners

      # finds all tests and partitions them into groups
      def self.tests_in_groups(tests, num_groups, options={})
        tests = find_tests(tests, options)

        if options[:group_by] == :found
          Grouper.in_groups(tests, num_groups)
        else
          tests = with_runtime_info(tests)
          Grouper.in_even_groups_by_size(tests, num_groups, options)
        end
      end

      def self.execute_command(cmd, process_number, options)
        cmd = "TEST_ENV_NUMBER=#{test_env_number(process_number)} ; export TEST_ENV_NUMBER; #{cmd}"
        f = open("|#{cmd}", 'r')
        output = fetch_output(f)
        f.close
        {:stdout => output, :exit_status => $?.exitstatus}
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

      def self.sum_up_results(results)
        results = results.join(' ').gsub(/s\b/,'') # combine and singularize results
        counts = results.scan(/(\d+) (\w+)/)
        sums = counts.inject(Hash.new(0)) do |sum, (number, word)|
          sum[word] += number.to_i
          sum
        end
        sums
      end

      # read output of the process and print in in chucks
      def self.fetch_output(process)
        all = ''
        while buffer = process.readpartial(1000000)
          all << buffer
          $stdout.print buffer
          $stdout.flush
        end rescue EOFError
        all
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

      def self.find_tests(tests, options={})
        (tests||[]).map do |file_or_folder|
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
