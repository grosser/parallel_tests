require 'parallel_specs/spec_logger_base'

class ParallelSpecs::SpecFailuresLogger < ParallelSpecs::SpecLoggerBase
  # RSpec 1 - called to dump 1 failed spec
  def dump_failure(*args)
    lock_output do
      super
    end
  end

  # RSpec 2 - called to dump all failed specs
  def dump_failures(*args)
    lock_output do
      super
    end
    @output.flush
  end
end
