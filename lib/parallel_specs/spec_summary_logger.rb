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

  def example_pending(example, *args)
    @pending_examples << example
  end

  def example_failed(example, *args)
    @failed_examples << example
  end

  def dump_summary(duration, example_count, failure_count, pending_count)
    lock_output do
      @output.puts "#{ @passed_examples.size } examples passed"
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
