require 'parallel_specs/spec_logger_base'

class ParallelSpecs::SpecRuntimeLogger < ParallelSpecs::SpecLoggerBase
  def initialize(options, output=nil)
    super
    @example_times = Hash.new(0)
  end

  def example_started(*args)
    @time = Time.now
  end

  def example_passed(example)
    file = example.location.split(':').first
    @example_times[file] += Time.now - @time
  end

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
