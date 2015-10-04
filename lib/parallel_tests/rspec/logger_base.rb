require 'tempfile'

module ParallelTests
  module RSpec
  end
end

begin
  require 'rspec/core/formatters/base_text_formatter'
  base = RSpec::Core::Formatters::BaseTextFormatter
rescue LoadError
  require 'spec/runner/formatter/base_text_formatter'
  base = Spec::Runner::Formatter::BaseTextFormatter
end

ParallelTests::RSpec::LoggerBaseBase = base

class ParallelTests::RSpec::LoggerBase < ParallelTests::RSpec::LoggerBaseBase
  RSPEC_1 = !defined?(RSpec::Core::Formatters::BaseTextFormatter) # do not test for Spec, this will trigger deprecation warning in rspec 2
  RSPEC_2 = !RSPEC_1 && RSpec::Core::Version::STRING.start_with?('2')
  RSPEC_3 = !RSPEC_1 && RSpec::Core::Version::STRING.start_with?('3')

  def initialize(*args)
    super

    @output ||= args[1] || args[0] # rspec 1 has output as second argument

    if String === @output # a path ?
      FileUtils.mkdir_p(File.dirname(@output))
      if temp_lock = Tempfile.open("#{File.basename(@output)}-lock", mode: File::LOCK_EX|File::LOCK_NB)
        File.open(@output, 'w'){} # overwrite previous results

        at_exit do
          unless temp_lock.closed?
            temp_lock.close
            temp_lock.unlink
          end
        end
      end
      @output = File.open(@output, 'a')
    elsif File === @output # close and restart in append mode
      @output.close
      @output = File.open(@output.path, 'a')
    end
  end

  #stolen from Rspec
  def close(*args)
    @output.close  if (IO === @output) & (@output != $stdout)
  end

  protected

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
