# frozen_string_literal: true
require 'parallel_tests/rspec/logger_base'
require 'parallel_tests/rspec/runner'

class ParallelTests::RSpec::FailuresLogger < ParallelTests::RSpec::LoggerBase
  RSpec::Core::Formatters.register(self, :dump_summary)

  def dump_summary(*args)
    lock_output do
      notification = args.first
      unless notification.failed_examples.empty?
        colorizer = ::RSpec::Core::Formatters::ConsoleCodes
        output.puts notification.colorized_rerun_commands(colorizer)
      end
    end
    @output.flush
  end
end
