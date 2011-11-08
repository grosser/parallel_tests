require 'parallel_specs/spec_logger_base'

class ParallelSpecs::SpecFailuresLogger < ParallelSpecs::SpecLoggerBase
  def initialize(options, output=nil)
    super
    @failed_examples = []
  end

  def example_failed(example, count, failure)
    @failed_examples << example
  end

  def dump_failure(*args)
    lock_output do
      @failed_examples.each.with_index do | example, i |
        spec_file = example.location.scan(/^[^:]+/)[0]
        spec_file.gsub!(%r(^.*?/spec/), './spec/')
        @output.puts "#{ParallelSpecs.executable} #{spec_file} -e \"#{example.description}\""
      end
    end
    @output.flush
  end

end
