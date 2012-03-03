require 'parallel_tests/rspec/failures_logger'

class ParallelTests::RSpec::SummaryLogger < ParallelTests::RSpec::LoggerBase
  # RSpec 1: dumps 1 failed spec
  def dump_failure(*args)
    lock_output do
      super
    end
    @output.flush
  end

  # RSpec 2: dumps all failed specs
  def dump_failures(*args)
    lock_output do
      super
    end
    @output.flush
  end
end
