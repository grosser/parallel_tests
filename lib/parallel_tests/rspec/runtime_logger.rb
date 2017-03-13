require 'parallel_tests'
require 'parallel_tests/rspec/logger_base'

class ParallelTests::RSpec::RuntimeLogger < ParallelTests::RSpec::LoggerBase
  def initialize(*args)
    super
    @example_times = Hash.new(0)
    @group_nesting = 0
  end

  unless RSPEC_2
    RSpec::Core::Formatters.register self, :example_group_started, :example_group_finished, :start_dump
  end

  def example_group_started(example_group)
    @time = ParallelTests.now if @group_nesting == 0
    @group_nesting += 1
    super
  end

  def example_group_finished(notification)
    @group_nesting -= 1
    if @group_nesting == 0
      path = (RSPEC_2 ? notification.file_path : notification.group.file_path)
      @example_times[path] += ParallelTests.now - @time
    end
    super if defined?(super)
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
        relative_path = file.sub(/^#{Regexp.escape Dir.pwd}\//,'').sub(/^\.\//, "")
        @output.puts "#{relative_path}:#{time > 0 ? time : 0}"
      end
    end
    @output.flush
  end
end
