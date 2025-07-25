# frozen_string_literal: true
require 'optparse'
require 'tempfile'
require 'parallel_tests'
require 'shellwords'
require 'pathname'

module ParallelTests
  class CLI
    def run(argv)
      Signal.trap("INT") { handle_interrupt }

      options = parse_options!(argv)

      ENV['DISABLE_SPRING'] ||= '1'

      num_processes = ParallelTests.determine_number_of_processes(options[:count])
      num_processes = (num_processes * ParallelTests.determine_multiple(options[:multiply_processes])).round

      options[:first_is_1] ||= first_is_1?

      if options[:execute]
        execute_command_in_parallel(options[:execute], num_processes, options)
      else
        run_tests_in_parallel(num_processes, options)
      end
    end

    private

    def handle_interrupt
      @graceful_shutdown_attempted ||= false
      Kernel.exit if @graceful_shutdown_attempted

      # In a shell, all sub-processes also get an interrupt, so they shut themselves down.
      # In a background process this does not happen and we need to do it ourselves.
      # We cannot always send the interrupt since then the sub-processes would get interrupted twice when in foreground
      # and that messes with interrupt handling.
      #
      # (can simulate detached with `(bundle exec parallel_rspec test/a_spec.rb -n 2 &)`)
      # also the integration test "passes on int signal to child processes" is detached.
      #
      # On windows getpgid does not work so we resort to always killing which is the smaller bug.
      #
      # The ParallelTests::Pids `synchronize` method can't be called directly from a trap,
      # using Thread workaround https://github.com/ddollar/foreman/issues/332
      Thread.new do
        if Gem.win_platform? || ((child_pid = ParallelTests.pids.all.first) && Process.getpgid(child_pid) != Process.pid)
          ParallelTests.stop_all_processes
        end
      end

      @graceful_shutdown_attempted = true
    end

    def execute_in_parallel(items, num_processes, options)
      Tempfile.open 'parallel_tests-lock' do |lock|
        ParallelTests.with_pid_file do
          simulate_output_for_ci options[:serialize_stdout] do
            Parallel.map_with_index(items, in_threads: num_processes) do |item, index|
              result = yield(item, index)
              reprint_output(result, lock.path) if options[:serialize_stdout]
              ParallelTests.stop_all_processes if options[:fail_fast] && result[:exit_status] != 0
              result
            end
          end
        end
      end
    end

    def run_tests_in_parallel(num_processes, options)
      test_results = nil

      run_tests_proc = -> do
        groups = @runner.tests_in_groups(options[:files], num_processes, options)
        groups.reject!(&:empty?)

        if options[:only_group]
          groups = options[:only_group].map { |i| groups[i - 1] }.compact
          num_processes = 1
        end

        report_number_of_tests(groups) unless options[:quiet]
        test_results = execute_in_parallel(groups, groups.size, options) do |group, index|
          run_tests(group, index, num_processes, options)
        end
        report_results(test_results, options) unless options[:quiet]
      end

      if options[:quiet]
        run_tests_proc.call
      else
        report_time_taken(&run_tests_proc)
      end

      if any_test_failed?(test_results)
        warn final_fail_message

        exit_status = if options[:failure_exit_code]
          options[:failure_exit_code]
        elsif options[:highest_exit_status]
          test_results.map { |data| data.fetch(:exit_status) }.max
        else
          1
        end

        exit exit_status
      end
    end

    def run_tests(group, process_number, num_processes, options)
      if (limit = options[:test_file_limit])
        # TODO: will have some bugs with summarizing results and last process
        results = group.each_slice(limit).map do |slice|
          @runner.run_tests(slice, process_number, num_processes, options)
        end
        result = results[0]
        results[1..].each do |res|
          result[:stdout] = result[:stdout].to_s + res[:stdout].to_s
          result[:exit_status] = [res[:exit_status], result[:exit_status]].max
          # adding all files back in, not using original cmd to show what was actually run
          result[:command] |= res[:command]
        end
        result
      else
        @runner.run_tests(group, process_number, num_processes, options)
      end
    end

    def reprint_output(result, lockfile)
      lock(lockfile) do
        $stdout.puts
        $stdout.puts result[:stdout]
        $stdout.flush
      end
    end

    def lock(lockfile)
      File.open(lockfile) do |lock|
        lock.flock File::LOCK_EX
        yield
      ensure
        # This shouldn't be necessary, but appears to be
        lock.flock File::LOCK_UN
      end
    end

    def report_results(test_results, options)
      results = @runner.find_results(test_results.map { |result| result[:stdout] } * "")
      puts ""
      puts @runner.summarize_results(results)

      report_failure_rerun_commmand(test_results, options)
    end

    def report_failure_rerun_commmand(test_results, options)
      failing_sets = test_results.reject { |r| r[:exit_status] == 0 }
      return if failing_sets.none?

      if options[:verbose] || options[:verbose_rerun_command]
        puts "\n\nTests have failed for a parallel_test group. Use the following command to run the group again:\n\n"
        failing_sets.each do |failing_set|
          command = failing_set[:command]
          command = @runner.command_with_seed(command, failing_set[:seed]) if failing_set[:seed]
          @runner.print_command(command, failing_set[:env] || {})
        end
      end
    end

    def report_number_of_tests(groups)
      name = @runner.test_file_name
      num_processes = groups.size
      num_tests = groups.map(&:size).sum
      tests_per_process = (num_processes == 0 ? 0 : num_tests / num_processes)
      puts "#{pluralize(num_processes, 'process')} for #{pluralize(num_tests, name)}, ~ #{pluralize(tests_per_process, name)} per process"
    end

    def pluralize(n, singular)
      if n == 1
        "1 #{singular}"
      elsif singular.end_with?('s', 'sh', 'ch', 'x', 'z')
        "#{n} #{singular}es"
      else
        "#{n} #{singular}s"
      end
    end

    # exit with correct status code so rake parallel:test && echo 123 works
    def any_test_failed?(test_results)
      test_results.any? { |result| result[:exit_status] != 0 }
    end

    def parse_options!(argv)
      newline_padding = 37 # poor man's way of getting a decent table like layout for -h output on 120 char width terminal
      options = {}

      OptionParser.new do |opts|
        opts.banner = <<~BANNER
          Run all tests in parallel, giving each process ENV['TEST_ENV_NUMBER'] ('', '2', '3', ...)

          [optional] Only selected files & folders:
            parallel_test test/bar test/baz/xxx_text.rb

          [optional] Pass test-options and files via `--`:
            parallel_test -- -t acceptance -f progress -- spec/foo_spec.rb spec/acceptance

          Options are:
        BANNER

        opts.on("-n PROCESSES", Integer, "How many processes to use, default: available CPUs") { |n| options[:count] = n }
        opts.on("-p", "--pattern PATTERN", "run tests matching this regex pattern") { |pattern| options[:pattern] = /#{pattern}/ }
        opts.on("--exclude-pattern", "--exclude-pattern PATTERN", "exclude tests matching this regex pattern") { |pattern| options[:exclude_pattern] = /#{pattern}/ }

        opts.on(
          "--group-by TYPE",
          heredoc(<<~TEXT, newline_padding)
            group tests by:
            found - order of finding files
            steps - number of cucumber/spinach steps
            scenarios - individual cucumber scenarios
            filesize - by size of the file
            runtime - info from runtime log
            default - runtime when runtime log is filled otherwise filesize
          TEXT
        ) { |type| options[:group_by] = type.to_sym }

        opts.on("-m COUNT", "--multiply-processes COUNT", Float, "use given number as a multiplier of processes to run") do |m|
          options[:multiply_processes] = m
        end

        opts.on("-s PATTERN", "--single PATTERN", "Run all matching files in the same process") do |pattern|
          (options[:single_process] ||= []) << /#{pattern}/
        end

        opts.on("-i", "--isolate", "Do not run any other tests in the group used by --single(-s)") do
          options[:isolate] = true
        end

        opts.on(
          "--isolate-n PROCESSES",
          Integer,
          "Use 'isolate'  singles with number of processes, default: 1"
        ) { |n| options[:isolate_count] = n }

        opts.on(
          "--highest-exit-status",
          "Exit with the highest exit status provided by test run(s)"
        ) { options[:highest_exit_status] = true }

        opts.on(
          "--failure-exit-code INT",
          Integer,
          "Specify the exit code to use when tests fail"
        ) { |code| options[:failure_exit_code] = code }

        opts.on(
          "--specify-groups SPECS",
          heredoc(<<~TEXT, newline_padding)
            Use 'specify-groups' if you want to specify multiple specs running in multiple
            processes in a specific formation. Commas indicate specs in the same process,
            pipes indicate specs in a new process. If SPECS is a '-' the value for this
            option is read from STDIN instead. Cannot use with --single, --isolate, or
            --isolate-n.  Ex.
            $ parallel_tests -n 3 . --specify-groups '1_spec.rb,2_spec.rb|3_spec.rb'
              Process 1 will contain 1_spec.rb and 2_spec.rb
              Process 2 will contain 3_spec.rb
              Process 3 will contain all other specs
          TEXT
        ) { |groups| options[:specify_groups] = groups }

        opts.on(
          "--only-group GROUP_INDEX[,GROUP_INDEX]",
          Array,
          heredoc(<<~TEXT, newline_padding)
            Only run the given group numbers.
            Changes `--group-by` default to 'filesize'.
          TEXT
        ) { |groups| options[:only_group] = groups.map(&:to_i) }

        opts.on("-e", "--exec COMMAND", "execute COMMAND in parallel and with ENV['TEST_ENV_NUMBER']") { |arg| options[:execute] = Shellwords.shellsplit(arg) }
        opts.on(
          "--exec-args COMMAND",
          heredoc(<<~TEXT, newline_padding)
            execute COMMAND in parallel with test files as arguments, for example:
            $ parallel_tests --exec-args echo
            > echo spec/a_spec.rb spec/b_spec.rb
          TEXT
        ) { |arg| options[:execute_args] = Shellwords.shellsplit(arg) }

        opts.on("-o", "--test-options 'OPTIONS'", "execute test commands with those options") { |arg| options[:test_options] = Shellwords.shellsplit(arg) }

        opts.on("-t", "--type TYPE", "test(default) / rspec / cucumber / spinach") do |type|
          @runner = load_runner(type)
        rescue NameError, LoadError => e
          puts "Runner for `#{type}` type has not been found! (#{e})"
          abort
        end

        opts.on(
          "--suffix PATTERN",
          heredoc(<<~TEXT, newline_padding)
            override built in test file pattern (should match suffix):
            '_spec.rb$' - matches rspec files
            '_(test|spec).rb$' - matches test or spec files
          TEXT
        ) { |pattern| options[:suffix] = /#{pattern}/ }

        opts.on("--serialize-stdout", "Serialize stdout output, nothing will be written until everything is done") { options[:serialize_stdout] = true }
        opts.on("--prefix-output-with-test-env-number", "Prefixes test env number to the output when not using --serialize-stdout") { options[:prefix_output_with_test_env_number] = true }
        opts.on("--combine-stderr", "Combine stderr into stdout, useful in conjunction with --serialize-stdout") { options[:combine_stderr] = true }
        opts.on("--non-parallel", "execute same commands but do not in parallel, needs --exec") { options[:non_parallel] = true }
        opts.on("--no-symlinks", "Do not traverse symbolic links to find test files") { options[:symlinks] = false }
        opts.on('--ignore-tags PATTERN', 'When counting steps ignore scenarios with tags that match this pattern') { |arg| options[:ignore_tag_pattern] = arg }
        opts.on("--nice", "execute test commands with low priority.") { options[:nice] = true }
        opts.on("--runtime-log PATH", "Location of previously recorded test runtimes") { |path| options[:runtime_log] = path }
        opts.on("--allowed-missing COUNT", Integer, "Allowed percentage of missing runtimes (default = 50)") { |percent| options[:allowed_missing_percent] = percent }
        opts.on('--allow-duplicates', 'When detecting files to run, allow duplicates') { options[:allow_duplicates] = true }
        opts.on("--unknown-runtime SECONDS", Float, "Use given number as unknown runtime (otherwise use average time)") { |time| options[:unknown_runtime] = time }
        opts.on("--first-is-1", "Use \"1\" as TEST_ENV_NUMBER to not reuse the default test environment") { options[:first_is_1] = true }
        opts.on("--fail-fast", "Stop all groups when one group fails (best used with --test-options '--fail-fast' if supported") { options[:fail_fast] = true }

        opts.on(
          "--test-file-limit LIMIT",
          Integer,
          heredoc(<<~TEXT, newline_padding)
            Limit to this number of files per test run by batching
            (for windows set to ~100 to stay below 8192 max command limit, might have bugs from reusing test-env-number
            and summarizing partial results)
          TEXT
        ) { |limit| options[:test_file_limit] = limit }

        opts.on("--verbose", "Print debug output") { options[:verbose] = true }
        opts.on("--verbose-command", "Combines options --verbose-process-command and --verbose-rerun-command") { options.merge! verbose_process_command: true, verbose_rerun_command: true }
        opts.on("--verbose-process-command", "Print the command that will be executed by each process before it begins") { options[:verbose_process_command] = true }
        opts.on("--verbose-rerun-command", "After a process fails, print the command executed by that process") { options[:verbose_rerun_command] = true }
        opts.on("--quiet", "Print only tests output") { options[:quiet] = true }
        opts.on("-v", "--version", "Show Version") do
          puts ParallelTests::VERSION
          exit 0
        end
        opts.on("-h", "--help", "Show this.") do
          puts opts
          exit 0
        end
      end.parse!(argv)

      raise "Both options are mutually exclusive: verbose & quiet" if options[:verbose] && options[:quiet]

      if options[:count] == 0
        options.delete(:count)
        options[:non_parallel] = true
      end

      files, remaining = extract_file_paths(argv)
      unless options[:execute]
        if files.empty?
          default_test_folder = @runner.default_test_folder
          if File.directory?(default_test_folder)
            files = [default_test_folder]
          else
            abort "Pass files or folders to run"
          end
        end
        options[:files] = files.map { |file_path| Pathname.new(file_path).cleanpath.to_s }
      end

      append_test_options(options, remaining)

      options[:group_by] ||= :filesize if options[:only_group]

      if options[:group_by] == :found && options[:single_process]
        raise "--group-by found and --single-process are not supported"
      end
      allowed = [:filesize, :runtime, :found]
      if !allowed.include?(options[:group_by]) && options[:only_group]
        raise "--group-by #{allowed.join(" or ")} is required for --only-group"
      end

      if options[:specify_groups] && options.keys.intersect?([:single_process, :isolate, :isolate_count])
        raise "Can't pass --specify-groups with any of these keys: --single, --isolate, or --isolate-n"
      end

      if options[:failure_exit_code] && options[:highest_exit_status]
        raise "Can't pass --failure-exit-code and --highest-exit-status"
      end

      options
    end

    def extract_file_paths(argv)
      dash_index = argv.rindex("--")
      file_args_at = (dash_index || -1) + 1
      [argv[file_args_at..], argv[0...(dash_index || 0)]]
    end

    def extract_test_options(argv)
      dash_index = argv.index("--") || -1
      argv[dash_index + 1..]
    end

    def append_test_options(options, argv)
      new_opts = extract_test_options(argv)
      return if new_opts.empty?

      options[:test_options] ||= []
      options[:test_options] += new_opts
    end

    def load_runner(type)
      require "parallel_tests/#{type}/runner"
      runner_classname = type.split("_").map(&:capitalize).join.sub("Rspec", "RSpec")
      klass_name = "ParallelTests::#{runner_classname}::Runner"
      klass_name.split('::').inject(Object) { |x, y| x.const_get(y) }
    end

    def execute_command_in_parallel(command, num_processes, options)
      runs = if options[:only_group]
        options[:only_group].map { |g| g - 1 }
      else
        (0...num_processes).to_a
      end
      results = if options[:non_parallel]
        ParallelTests.with_pid_file do
          runs.map do |i|
            ParallelTests::Test::Runner.execute_command(command, i, num_processes, options)
          end
        end
      else
        execute_in_parallel(runs, runs.size, options) do |i|
          ParallelTests::Test::Runner.execute_command(command, i, num_processes, options)
        end
      end.flatten

      abort if results.any? { |r| r[:exit_status] != 0 }
    end

    def report_time_taken(&block)
      seconds = ParallelTests.delta(&block).to_i
      puts "\nTook #{seconds} seconds#{detailed_duration(seconds)}"
    end

    def detailed_duration(seconds)
      parts = [seconds / 3600, seconds % 3600 / 60, seconds % 60].drop_while(&:zero?)
      return if parts.size < 2
      parts = parts.map { |i| "%02d" % i }.join(':').sub(/^0/, '')
      " (#{parts})"
    end

    def final_fail_message
      fail_message = "Tests Failed"
      fail_message = "\e[31m#{fail_message}\e[0m" if use_colors?
      fail_message
    end

    def use_colors?
      $stdout.tty?
    end

    def first_is_1?
      val = ENV["PARALLEL_TEST_FIRST_IS_1"]
      ['1', 'true'].include?(val)
    end

    # CI systems often fail when there is no output for a long time, so simulate some output
    def simulate_output_for_ci(simulate)
      if simulate
        progress_indicator = Thread.new do
          interval = Float(ENV['PARALLEL_TEST_HEARTBEAT_INTERVAL'] || 60)
          loop do
            sleep interval
            print '.'
          end
        end
        test_results = yield
        progress_indicator.exit
        test_results
      else
        yield
      end
    end

    def heredoc(text, newline_padding)
      text.rstrip.gsub("\n", "\n#{' ' * newline_padding}")
    end
  end
end
