require 'optparse'


module ParallelTests
  class CLI

    # @param runner [Class] one of the test runner classes like test unit, rspec or
    #  cucumber runners.
    #
    # @return [void]
    def initialize(runner)
      @runner = runner
    end

    def run(argv)
      options = parse_options!(argv)

      num_processes = ParallelTests.determine_number_of_processes(options[:count])
      num_processes = num_processes * (options[:multiply] || 1)

      if options[:execute]
        execute_shell_command_in_parallel(options[:execute], num_processes, options)
      else
        run_tests_in_parallel(num_processes, options)
      end
    end

    private

    def run_tests_in_parallel(num_processes, options)
      test_results = nil

      report_time_taken do
        groups = @runner.tests_in_groups(options[:files], num_processes, options)
        report_number_of_tests(groups)

        test_results = Parallel.map(groups, :in_processes => groups.size) do |group|
          run_tests(group, groups.index(group), num_processes, options)
        end

        report_results(test_results)
      end

      abort final_fail_message if any_test_failed?(test_results)
    end

    def run_tests(group, process_number, num_processes, options)
      if group.empty?
        {:stdout => '', :exit_status => 0}
      else
        @runner.run_tests(group, process_number, num_processes, options)
      end
    end

    def report_results(test_results)
      results = @runner.find_results(test_results.map { |result| result[:stdout] }*"")
      puts ""
      puts @runner.summarize_results(results)
    end

    def report_number_of_tests(groups)
      name = @runner.test_file_name
      num_processes = groups.size
      num_tests = groups.map(&:size).inject(:+)
      puts "#{num_processes} processes for #{num_tests} #{name}s, ~ #{num_tests / groups.size} #{name}s per process"
    end

    #exit with correct status code so rake parallel:test && echo 123 works
    def any_test_failed?(test_results)
      test_results.any? { |result| result[:exit_status] != 0 }
    end

    def parse_options!(argv)
      options = {}
      OptionParser.new do |opts|
        opts.banner = <<BANNER
Run all tests in parallel, giving each process ENV['TEST_ENV_NUMBER'] ('', '2', '3', ...)

[optional] Only run selected files & folders:
    parallel_test test/bar test/baz/xxx_text.rb

Options are:
BANNER
        opts.on("-n [PROCESSES]", Integer, "How many processes to use, default: available CPUs") { |n| options[:count] = n }
        opts.on("-p", "--pattern [PATTERN]", "run tests matching this pattern") { |pattern| options[:pattern] = /#{pattern}/ }
        opts.on("--group-by [TYPE]", <<-TEXT
group tests by:
          found - order of finding files
          steps - number of cucumber steps
          default - runtime or filesize
TEXT
) { |type| options[:group_by] = type.to_sym }
        opts.on("-m [FLOAT]", "--multiply-processes [FLOAT]", Float, "use given number as a multiplier of processes to run") { |multiply| options[:multiply] = multiply }

        opts.on("-s [PATTERN]", "--single [PATTERN]",
          "Run all matching files in the same process") do |pattern|

          options[:single_process] ||= []
          options[:single_process] << /#{pattern}/
        end

        opts.on("-i", "--isolate",
          "Do not run any other tests in the group used by --single(-s)") do |pattern|

          options[:isolate] = true
        end

        opts.on("-e", "--exec [COMMAND]", "execute this code parallel and with ENV['TEST_ENV_NUM']") { |path| options[:execute] = path }
        opts.on("-o", "--test-options '[OPTIONS]'", "execute test commands with those options") { |arg| options[:test_options] = arg }
        opts.on("-t", "--type [TYPE]", "test(default) / rspec / cucumber") do |type|
          klass_name = "ParallelTests::#{type.capitalize.sub('Rspec', 'RSpec')}::Runner"
          begin
            klass = klass_name.split('::').inject(Object) { |x, y| x.const_get(y) }
            @runner = klass
          rescue NameError => e
            puts "Unknown type: #{type}"
            puts "Runner `#{klass_name}` for `#{type}` type has not been found!\n"

            abort
          end
        end
        opts.on("--non-parallel", "execute same commands but do not in parallel, needs --exec") { options[:non_parallel] = true }
        opts.on("--no-symlinks", "Do not traverse symbolic links to find test files") { options[:symlinks] = false }
        opts.on('--ignore-tags [PATTERN]', 'When counting steps ignore scenarios with tags that match this pattern')  { |arg| options[:ignore_tag_pattern] = arg }
        opts.on("-v", "--version", "Show Version") { puts ParallelTests::VERSION; exit }
        opts.on("-h", "--help", "Show this.") { puts opts; exit }
      end.parse!(argv)

      raise "--group-by found and --single-process are not supported" if options[:group_by] == :found and options[:single_process]

      if options[:count] == 0
        options.delete(:count)
        options[:non_parallel] = true
      end

      options[:files] = argv
      options
    end

    def execute_shell_command_in_parallel(command, num_processes, options)
      runs = (0...num_processes).to_a
      results = if options[:non_parallel]
        runs.map do |i|
          ParallelTests::Test::Runner.execute_command(command, i, num_processes)
        end
      else
        Parallel.map(runs, :in_processes => num_processes) do |i|
          ParallelTests::Test::Runner.execute_command(command, i, num_processes)
        end
      end.flatten

      abort if results.any? { |r| r[:exit_status] != 0 }
    end

    def report_time_taken
      start = Time.now
      yield
      puts "\nTook #{Time.now - start} seconds"
    end

    def final_fail_message
      fail_message = "#{@runner.name}s Failed"
      fail_message = "\e[31m#{fail_message}\e[0m" if use_colors?

      fail_message
    end

    def use_colors?
      $stdout.tty?
    end
  end
end
