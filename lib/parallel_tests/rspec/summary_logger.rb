require 'parallel_tests/rspec/failures_logger'

class ParallelTests::RSpec::SummaryLogger < ParallelTests::RSpec::LoggerBase
  if RSPEC_3
    RSpec::Core::Formatters.register self, :dump_failures
  end

  if RSPEC_1
    def dump_failure(*args)
      lock_output { super }
      @output.flush
    end
  else
    def dump_failures(*args)
      lock_output { super }
      @output.flush
    end
  end
end
