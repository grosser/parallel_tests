# frozen_string_literal: true
require 'parallel_tests'
require 'parallel_tests/rspec/logger_base'

class ParallelTests::RSpec::RuntimeLogger < ParallelTests::RSpec::LoggerBase
  def initialize(*args)
    super
    @example_times = Hash.new(0)
    @group_nesting = 0
  end

  RSpec::Core::Formatters.register self, :example_group_started, :example_group_finished, :start_dump unless RSPEC_2

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

  def dump_summary(*); end

  def dump_failures(*); end

  def dump_failure(*); end

  def dump_pending(*); end

  def start_dump(*)
    return unless ENV['TEST_ENV_NUMBER'] # only record when running in parallel
    lock_output do
      @example_times.each do |file, time|
        relative_path = file.sub(%r{^#{Regexp.escape Dir.pwd}/}, '').sub(%r{^\./}, "")
        @output.puts "#{relative_path}:#{time > 0 ? time : 0}"
      end
    end
    @output.flush
  end
end
