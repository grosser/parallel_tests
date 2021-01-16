require 'parallel_tests/rspec/failures_logger'

class ParallelTests::RSpec::SummaryLogger < ParallelTests::RSpec::LoggerBase
  RSpec::Core::Formatters.register self, :dump_failures unless RSPEC_2

  def dump_failures(*args)
    lock_output { super }
    @output.flush
  end
end
