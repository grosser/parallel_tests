require 'optparse'
require 'parallel_tests/test/runner'

module ParallelTest
  module CLI
    def self.run(argv)
      options = parse_options!(argv)
      test_results = nil

      num_processes = ParallelTests.determine_number_of_processes(options[:count])
      num_processes = num_processes * (options[:multiply] || 1)

      if options[:execute]
        execute_shell_command_in_parallel(options[:execute], num_processes, options)
      else
        lib = options[:type] || 'test'
        require "parallel_tests/#{lib}/runner"
        runner = eval("ParallelTests::#{lib.capitalize}::Runner")
        name = runner.test_file_name

        report_time_taken do
          groups = runner.tests_in_groups(options[:files], num_processes, options)
          abort "no #{name}s found!" if groups.size == 0

          num_processes = groups.size
          num_tests = groups.inject(0) { |sum, item| sum + item.size }
          puts "#{num_processes} processes for #{num_tests} #{name}s, ~ #{num_tests / groups.size} #{name}s per process"

          test_results = Parallel.map(groups, :in_processes => num_processes) do |group|
            if group.empty?
              {:stdout => '', :exit_status => 0}
            else
              runner.run_tests(group, groups.index(group), options)
            end
          end

          #parse and print results
          results = runner.find_results(test_results.map { |result| result[:stdout] }*"")
          puts ""
          puts runner.summarize_results(results)
        end

        #exit with correct status code so rake parallel:test && echo 123 works
        failed = test_results.any? { |result| result[:exit_status] != 0 }
        abort "#{lib.capitalize}s Failed" if failed
      end
    end

    private

    def self.parse_options!(argv)
      options = {}
      OptionParser.new do |opts|
        opts.banner = <<BANNER
Run all tests in parallel, giving each process ENV['TEST_ENV_NUMBER'] ('', '2', '3', ...)

[optional] Only run selected files & folders:
    parallel_test test/bar test/baz/xxx_text.rb

Options are:
BANNER
        opts.on("-n [PROCESSES]", Integer, "How many processes to use, default: available CPUs") { |n| options[:count] = n }
        opts.on("-p", '--pattern [PATTERN]', "run tests matching this pattern") { |pattern| options[:pattern] = pattern }
        opts.on("--no-sort", "do not sort files before running them") { |no_sort| options[:no_sort] = no_sort }
        opts.on("-m [FLOAT]", "--multiply-processes [FLOAT]", Float, "use given number as a multiplier of processes to run") { |multiply| options[:multiply] = multiply }
        opts.on("-s [PATTERN]", "--single [PATTERN]", "Run all matching files in only one process") do |pattern|
          options[:single_process] ||= []
          options[:single_process] << /#{pattern}/
        end
        opts.on("-e", '--exec [COMMAND]', "execute this code parallel and with ENV['TEST_ENV_NUM']") { |path| options[:execute] = path }
        opts.on("-o", "--test-options '[OPTIONS]'", "execute test commands with those options") { |arg| options[:test_options] = arg }
        opts.on("-t", "--type [TYPE]", "test(default) / spec / cucumber") { |type| options[:type] = type }
        opts.on("--non-parallel", "execute same commands but do not in parallel, needs --exec") { options[:non_parallel] = true }
        opts.on("--chunk-timeout [TIMEOUT]", "timeout before re-printing the output of a child-process") { |timeout| options[:chunk_timeout] = timeout.to_f }
        opts.on('-v', '--version', 'Show Version') { puts ParallelTests::VERSION; exit }
        opts.on("-h", "--help", "Show this.") { puts opts; exit }
      end.parse!(argv)

      raise "--no-sort and --single-process are not supported" if options[:no_sort] and options[:single_process]

      options[:files] = argv
      options
    end

    def self.execute_shell_command_in_parallel(command, num_processes, options)
      runs = (0...num_processes).to_a
      results = if options[:non_parallel]
        runs.map do |i|
          ParallelTests::Test::Runner.execute_command(command, i, options)
        end
      else
        Parallel.map(runs, :in_processes => num_processes) do |i|
          ParallelTests::Test::Runner.execute_command(command, i, options)
        end
      end.flatten

      abort if results.any? { |r| r[:exit_status] != 0 }
    end

    def self.report_time_taken
      start = Time.now
      yield
      puts ""
      puts "Took #{Time.now - start} seconds"
    end
  end
end
