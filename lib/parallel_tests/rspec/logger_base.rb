module ParallelTests
  module RSpec
  end
end

require 'rspec/core/formatters/base_text_formatter'

class ParallelTests::RSpec::LoggerBase < RSpec::Core::Formatters::BaseTextFormatter
  RSPEC_2 = RSpec::Core::Version::STRING.start_with?('2')

  def initialize(*args)
    super

    @output ||= args[0]

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
