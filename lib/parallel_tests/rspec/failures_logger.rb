require 'parallel_tests/rspec/logger_base'
require 'parallel_tests/rspec/runner'

class ParallelTests::RSpec::FailuresLogger < ParallelTests::RSpec::LoggerBase
  if RSPEC_2
    def dump_failures(*args)
    end
  else
    RSpec::Core::Formatters.register self, :dump_summary
  end

  def dump_summary(*args)
    lock_output do
      if RSPEC_3
        notification = args.first
        unless notification.failed_examples.empty?
          colorizer = ::RSpec::Core::Formatters::ConsoleCodes
          output.puts notification.colorized_rerun_commands(colorizer)
        end
      else
        dump_commands_to_rerun_failed_examples
      end
    end
    @output.flush
  end
end
