# frozen_string_literal: true
require 'parallel_tests/rspec/failures_logger'

class ParallelTests::RSpec::SummaryLogger < ParallelTests::RSpec::LoggerBase
  RSpec::Core::Formatters.register(self, :dump_failures)

  def dump_failures(*args)
    lock_output { super }
    @output.flush
  end
end
