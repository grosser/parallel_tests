require 'parallel_specs'

begin
  require 'rspec/core/formatters/progress_formatter'
  base = RSpec::Core::Formatters::ProgressFormatter
rescue LoadError
  require 'spec/runner/formatter/progress_bar_formatter'
  base = Spec::Runner::Formatter::BaseTextFormatter
end
ParallelSpecs::SpecRuntimeLoggerBase = base

class ParallelSpecs::SpecRuntimeLogger < ParallelSpecs::SpecRuntimeLoggerBase
  def initialize(options, output=nil)
    output ||= options # rspec 2 has output as first argument

    if String === output
      FileUtils.mkdir_p(File.dirname(output))
      File.open(output,'w'){|f| f.write ''} # clean the file
      @output = File.open(output, 'a+') #append so that multiple processes can write at once
    else
      @output = output
    end
    @example_times = Hash.new(0)
    @failed_examples = [] # only needed for rspec 2
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
      @output.puts @example_times.map { |file, time| "#{file}:#{time > 0 ? time : 0}" }
    end
    @output.flush
  end

  # stubs so that rspec doe not crash

  def example_pending(*args)
  end

  def dump_summary(*args)
  end

  def dump_pending(*args)
  end

  def dump_failure(*args)
  end

  #stolen from Rspec
  def close
    @output.close  if (IO === @output) & (@output != $stdout)
  end

  # do not let multiple processes get in each others way
  def lock_output
    if File === @output
      begin
        @output.flock File::LOCK_EX
        yield
      ensure
        @output.flock File::LOCK_UN
      end
    else
      yield
    end
  end
end
