require 'parallel_specs/spec_logger_base'

class ParallelSpecs::SpecFailuresLogger < ParallelSpecs::SpecLoggerBase
  def dump_summary(*args)
    # no additional dumping, just failures
  end

  # RSpec 1 - called to dump 1 failed spec
  def dump_failure(*args)
    lock_output do
      super
    end
  end

  # RSpec 2 - called to dump all failed specs
  def dump_failures(*args)
    lock_output do
      @failed_examples.each do |example|
        next unless example.location
        file, line = example.location.split(':')
        file.gsub!(%r(^.*?/spec/), './spec/')
        @output.puts "#{ParallelSpecs.executable} #{file}:#{line} # #{example.description}"
      end
    end
    @output.flush
  end
end
