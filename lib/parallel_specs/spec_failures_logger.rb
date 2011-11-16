require 'parallel_specs/spec_logger_base'

class ParallelSpecs::SpecFailuresLogger < ParallelSpecs::SpecLoggerBase
  def dump_failures(*args)
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
