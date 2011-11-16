require 'parallel_specs/spec_failures_logger'

class ParallelSpecs::SpecSummaryLogger < ParallelSpecs::SpecFailuresLogger
  def dump_summary(duration, example_count, failure_count, pending_count)
    lock_output do
      @output.puts "#{example_count} run, #{failure_count} failed, #{pending_count} pending"
    end
    @output.flush
  end

  # TODO collect and then dump failure backtraces
end
