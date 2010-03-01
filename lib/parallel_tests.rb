require 'parallel'

class ParallelTests
  VERSION = File.read( File.join(File.dirname(__FILE__),'..','VERSION') ).strip

  # parallel:spec[2,controller] <-> parallel:spec[controller]
  def self.parse_rake_args (args)
    num_processes = Parallel.processor_count
    options = ""
    if args[:count].to_s =~ /^\d*$/ # number or empty
      num_processes = args[:count] unless args[:count].to_s.empty?
      prefix = args[:path_prefix]
      options = args[:options] if args[:options]
    else # something stringy
      prefix = args[:count]
    end
    [num_processes.to_i, prefix.to_s, options]
  end

  # finds all tests and partitions them into groups
  def self.tests_in_groups(root, num)
    tests_with_sizes = slow_specs_first(find_tests_with_sizes(root))

    groups = []
    current_group = current_size = 0
    tests_with_sizes.each do |test, size|
      # inserts into next group if current is full and we are not in the last group
      if (0.5*size + current_size) > group_size(tests_with_sizes, num) and num > current_group + 1
        current_size = size
        current_group += 1
      else
        current_size += size
      end
      groups[current_group] ||= []
      groups[current_group] << test
    end
    groups.compact
  end

  def self.run_tests(test_files, process_number, options)
    require_list = test_files.map { |filename| "\"#{filename}\"" }.join(",")
    cmd = "export RAILS_ENV=test ; ruby -Itest #{options} -e '[#{require_list}].each {|f| require f }'"
    execute_command(cmd, process_number)
  end

  def self.execute_command(cmd, process_number)
    cmd = "export TEST_ENV_NUMBER=#{test_env_number(process_number)} ; #{cmd}"
    f = open("|#{cmd}", 'r')
    all = ''
    while char = f.getc
      char = (char.is_a?(Fixnum) ? char.chr : char) # 1.8 <-> 1.9
      all << char
      print char
      STDOUT.flush
    end
    all
  end

  def self.find_results(test_output)
    test_output.split("\n").map {|line|
      line = line.gsub(/\.|F|\*/,'')
      next unless line_is_result?(line)
      line
    }.compact
  end

  def self.failed?(results)
    return true if results.empty?
    !! results.detect{|line| line_is_failure?(line)}
  end

  def self.test_env_number(process_number)
    process_number == 0 ? '' : process_number + 1
  end

  protected

  def self.slow_specs_first(tests)
    tests.sort_by{|test, size| size }.reverse
  end
  
  def self.line_is_result?(line)
    line =~ /\d+ failure/
  end
  
  def self.line_is_failure?(line)
    line =~ /(\d{2,}|[1-9]) (failure|error)/
  end

  def self.group_size(tests_with_sizes, num_groups)
    total_size = tests_with_sizes.inject(0) { |sum, test| sum += test[1] }
    total_size / num_groups.to_f
  end

  def self.find_tests_with_sizes(root)
    tests = find_tests(root).sort

    #TODO get the real root, atm this only works for complete runs when root point to e.g. real_root/spec
    runtime_file = File.join(root,'..','tmp','parallel_profile.log')
    lines = File.read(runtime_file).split("\n") rescue []

    if lines.size * 1.5 > tests.size
      # use recorded test runtime if we got enough data
      times = Hash.new(1)
      lines.each do |line|
        test, time = line.split(":")
        times[test] = time.to_f
      end
      tests.map { |test| [ test, times[test] ] }
    else
      # use file sizes
      tests.map { |test| [ test, File.stat(test).size ] }
    end
  end

  def self.find_tests(root)
    Dir["#{root}**/**/*_test.rb"]
  end
end
