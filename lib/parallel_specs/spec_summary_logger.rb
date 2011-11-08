require 'parallel_specs/spec_logger_base'

class ParallelSpecs::SpecSummaryLogger < ParallelSpecs::SpecLoggerBase
  def initialize(options, output=nil)
    super
    @passed_examples = []
    @pending_examples = []
    @failed_examples = []
  end

  def example_passed(example)
    @passed_examples << example
  end

  def example_pending(*args)
    @pending_examples << args
  end

  def example_failed(example, count, failure)
    @failed_examples << failure
  end

  def dump_summary(duration, example_count, failure_count, pending_count)
    lock_output do
      @output.puts "#{ @passed_examples.size } examples passed"
    end
    @output.flush
  end

  def dump_failure(*args)
    lock_output do
      @output.puts "#{ @failed_examples.size } examples failed:"
      @failed_examples.each.with_index do | failure, i |
        @output.puts "#{ i + 1 })"
        @output.puts failure.header
        @output.puts failure.exception.to_s
        failure.exception.backtrace.each do | caller |
          @output.puts caller
        end
        @output.puts ''
      end
    end
    @output.flush
  end

end
