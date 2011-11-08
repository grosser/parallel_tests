require 'parallel'
require 'parallel_tests/grouper'
require 'parallel_tests/railtie'

class ParallelTests
  VERSION = File.read( File.join(File.dirname(__FILE__),'..','VERSION') ).strip

  # parallel:spec[:count, :pattern, :options]
  def self.parse_rake_args(args)
    # order as given by user
    args = [args[:count], args[:pattern], args[:options]]

    # count given or empty ?
    # parallel:spec[2,models,options]
    # parallel:spec[,models,options]
    count = args.shift if args.first.to_s =~ /^\d*$/
    num_processes = count.to_i unless count.to_s.empty?
    num_processes ||= ENV['PARALLEL_TEST_PROCESSORS'].to_i if ENV['PARALLEL_TEST_PROCESSORS']
    num_processes ||= Parallel.processor_count

    pattern = args.shift
    options = args.shift

    [num_processes.to_i, pattern.to_s, options.to_s]
  end

  # finds all tests and partitions them into groups
  def self.tests_in_groups(root, num_groups, options={})
    tests = find_tests(root, options)
    if options[:no_sort] == true
      Grouper.in_groups(tests, num_groups)
    else
      tests = with_runtime_info(tests)
      Grouper.in_even_groups_by_size(tests, num_groups, options)
    end
  end

  def self.run_tests(test_files, process_number, options)
    require_list = test_files.map { |filename| %{"#{File.expand_path filename}"} }.join(",")
    cmd = "ruby -Itest -e '[#{require_list}].each {|f| require f }' -- #{options[:test_options]}"
    execute_command(cmd, process_number, options)
  end

  def self.execute_command(cmd, process_number, options)
    cmd = "TEST_ENV_NUMBER=#{test_env_number(process_number)} ; export TEST_ENV_NUMBER; #{cmd}"
    f = open("|#{cmd}", 'r')
    output = fetch_output(f, options)
    f.close
    {:stdout => output, :exit_status => $?.exitstatus}
  end

  def self.find_results(test_output)
    test_output.split("\n").map {|line|
      line = line.gsub(/\.|F|\*/,'')
      next unless line_is_result?(line)
      line
    }.compact
  end

  def self.test_env_number(process_number)
    process_number == 0 ? '' : process_number + 1
  end

  def self.runtime_log
    'tmp/parallel_runtime_test.log'
  end

  def self.summarize_results(results)
    results = results.join(' ').gsub(/s\b/,'') # combine and singularize results
    counts = results.scan(/(\d+) (\w+)/)
    sums = counts.inject(Hash.new(0)) do |sum, (number, word)|
      sum[word] += number.to_i
      sum
    end
    sums.sort.map{|word, number|  "#{number} #{word}#{'s' if number != 1}" }.join(', ')
  end

  protected

  # read output of the process and print in in chucks
  def self.fetch_output(process, options)
    all = ''
    buffer = ''
    timeout = options[:chunk_timeout] || 0.2
    flushed = Time.now.to_f

    while char = process.getc
      char = (char.is_a?(Fixnum) ? char.chr : char) # 1.8 <-> 1.9
      all << char

      # print in chunks so large blocks stay together
      now = Time.now.to_f
      buffer << char
      if flushed + timeout < now
        print buffer
        STDOUT.flush
        buffer = ''
        flushed = now
      end
    end

    # print the remainder
    print buffer
    STDOUT.flush

    all
  end

  # copied from http://github.com/carlhuda/bundler Bundler::SharedHelpers#find_gemfile
  def self.bundler_enabled?
    return true if Object.const_defined?(:Bundler)

    previous = nil
    current = File.expand_path(Dir.pwd)

    until !File.directory?(current) || current == previous
      filename = File.join(current, "Gemfile")
      return true if File.exists?(filename)
      current, previous = File.expand_path("..", current), current
    end

    false
  end

  def self.line_is_result?(line)
    line =~ /\d+ failure/
  end

  def self.test_suffix
    "_test.rb"
  end

  def self.with_runtime_info(tests)
    lines = File.read(runtime_log).split("\n") rescue []

    # use recorded test runtime if we got enough data
    if lines.size * 1.5 > tests.size
      puts "Using recorded test runtime"
      times = Hash.new(1)
      lines.each do |line|
        test, time = line.split(":")
        times[File.expand_path(test)] = time.to_f
      end
      tests.sort.map{|test| [test, times[test]] }
    else # use file sizes
      tests.sort.map{|test| [test, File.stat(test).size] }
    end
  end

  def self.find_tests(root, options={})
    if root.is_a?(Array)
      root
    else
      # follow one symlink and direct children
      # http://stackoverflow.com/questions/357754/can-i-traverse-symlinked-directories-in-ruby-with-a-glob
      files = Dir["#{root}/**{,/*/**}/*#{test_suffix}"].uniq
      files = files.map{|f| f.sub(root+'/','') }
      files = files.grep(/#{options[:pattern]}/)
      files.map{|f| "#{root}/#{f}" }
    end
  end
end
