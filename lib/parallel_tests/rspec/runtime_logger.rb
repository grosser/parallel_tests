require 'parallel_tests'
require 'parallel_tests/rspec/logger_base'

class ParallelTests::RSpec::RuntimeLogger < ParallelTests::RSpec::LoggerBase
  def initialize(*args)
    super
    @example_times = Hash.new(0)
    @group_nesting = 0 if !RSPEC_1
  end

  if RSPEC_1
    def example_started(*args)
      @time = ParallelTests.now
      super
    end

    def example_passed(example)
      file = example.location.split(':').first
      @example_times[file] += ParallelTests.now - @time
      super
    end
  else
    def example_group_started(example_group)
      if @group_nesting == 0
        @time = ParallelTests.now
      end
      @group_nesting += 1
      super
    end

    def example_group_finished(example_group)
      @group_nesting -= 1
      if @group_nesting == 0
        @example_times[example_group.file_path] = ParallelTests.now - @time
      end
      super
    end
  end

  def dump_summary(*args);end
  def dump_failures(*args);end
  def dump_failure(*args);end
  def dump_pending(*args);end

  def start_dump(*args)
    return unless ENV['TEST_ENV_NUMBER'] #only record when running in parallel
    # TODO: Figure out why sometimes time can be less than 0
    lock_output do
      @example_times.each do |file, time|
        relative_path = file.sub(/^#{Regexp.escape Dir.pwd}\//,'')
        @output.puts "#{relative_path}:#{time > 0 ? time : 0}"
      end
    end
    @output.flush
  end
end
