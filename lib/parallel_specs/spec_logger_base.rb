require 'parallel_specs'

begin
  require 'rspec/core/formatters/base_text_formatter'
  base = RSpec::Core::Formatters::BaseTextFormatter
rescue LoadError
  require 'spec/runner/formatter/base_text_formatter'
  base = Spec::Runner::Formatter::BaseTextFormatter
end
ParallelSpecs::SpecLoggerBaseBase = base

class ParallelSpecs::SpecLoggerBase < ParallelSpecs::SpecLoggerBaseBase
  def initialize(*args)
    super

    @output ||= args[1] || args[0] # rspec 1 has output as second argument

    if String === @output # a path ?
      FileUtils.mkdir_p(File.dirname(@output))
      File.open(@output, 'w'){} # overwrite previous results
      @output = File.open(@output, 'a')
    elsif File === @output # close and restart in append mode
      @output.close
      @output = File.open(@output.path, 'a')
    end
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

  def rspec_1?
    defined? Spec::Runner
  end
end
