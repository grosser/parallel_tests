require 'parallel_specs/spec_failures_logger'

class ParallelSpecs::SpecSummaryLogger < ParallelSpecs::SpecFailuresLogger
  def dump_summary(duration, example_count, failure_count, pending_count)
    lock_output do
      @output.puts "#{example_count} run, #{failure_count} failed, #{pending_count} pending"
    end
    @output.flush
  end

  def dump_failure(*args)
    return if @failed_examples.size == 0

    lock_output do
      @output.puts "#{@failed_examples.size} examples failed:"
      @failed_examples.each.with_index do |failure, i|
        @output.puts "#{ i + 1 })"
        @output.puts failure.header
        @output.puts failure.exception.to_s
        failure.exception.backtrace.each do |caller|
          @output.puts caller
        end
        @output.puts ''
      end
    end

    super # dump failures
  end
end
