require 'parallel_tests/rspec/logger_base'
require 'parallel_tests/rspec/runner'

class ParallelTests::RSpec::FailuresLogger < ParallelTests::RSpec::LoggerBase
  def example_failed(example, *args)
    super
  end

  # RSpec 2: dumps all failed specs
  def dump_failures(*args)
  end

  def dump_summary(*args)
    lock_output do
      dump_commands_to_rerun_failed_examples
    end
    @output.flush
  end
end
