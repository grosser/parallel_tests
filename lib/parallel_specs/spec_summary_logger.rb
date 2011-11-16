require 'parallel_specs/spec_logger_base'

class ParallelSpecs::SpecSummaryLogger < ParallelSpecs::SpecLoggerBase
  def dump_summary(duration, example_count, failure_count, pending_count)
    lock_output do
      @output.puts "#{example_count} run, #{failure_count} failed, #{pending_count} pending"
    end
    @output.flush
  end

  def dump_failure(*args)
    lock_output do
      @failed_examples.each do |example|
        file, line = example.location.split(':')
        file.gsub!(%r(^.*?/spec/), './spec/')
        @output.puts "#{ParallelSpecs.executable} #{file}:#{line} # #{example.description}"
      end
    end
    @output.flush
  end
end
