require 'parallel_tests/spec/failures_logger'

class ParallelTests::Spec::SummaryLogger < ParallelTests::Spec::LoggerBase
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
