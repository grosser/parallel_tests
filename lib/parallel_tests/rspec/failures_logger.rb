require 'parallel_tests/rspec/logger_base'
require 'parallel_tests/rspec/runner'

class ParallelTests::RSpec::FailuresLogger < ParallelTests::RSpec::LoggerBase
  if RSPEC_3
    RSpec::Core::Formatters.register self, :dump_failures, :dump_summary
  end

  # RSpec 1: does not keep track of failures, so we do
  def example_failed(example, *args)
    if RSPEC_1
      @failed_examples ||= []
      @failed_examples << example
    else
      super
    end
  end

  if RSPEC_1
    def dump_failure(*args)
    end
  else
    def dump_failures(*args)
    end
  end

  def dump_summary(*args)
    lock_output do
      if RSPEC_1
        dump_commands_to_rerun_failed_examples_rspec_1
      elsif RSPEC_3
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

  private

  def dump_commands_to_rerun_failed_examples_rspec_1
    (@failed_examples||[]).each do |example|
      file, line = example.location.to_s.split(':')
      next unless file and line
      file.gsub!(%r(^.*?/spec/), './spec/')
      @output.puts "#{ParallelTests::RSpec::Runner.send(:executable)} #{file}:#{line} # #{example.description}"
    end
  end
end
