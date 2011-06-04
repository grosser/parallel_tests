class ParallelCucumber
  class RuntimeLogger

    def initialize(step_mother, path_or_io, options=nil)
      @io = prepare_io(path_or_io)
      @example_times = Hash.new(0)
    end

    def before_feature(_)
      @start_at = Time.now.to_f
    end

    def after_feature(feature)
      @example_times[feature.file] += Time.now.to_f - @start_at
    end

    def after_features(*args)
      lock_output do
        @io.puts @example_times.map { |file, time| "#{file}:#{time}" }
      end
    end

    private

    def prepare_io(path_or_io)
      if path_or_io.respond_to?(:write)
        path_or_io
      else # its a path
        File.open(path_or_io, 'w').close # clean out the file
        file = File.open(path_or_io, 'a')

        at_exit do
          unless file.closed?
            file.flush
            file.close
          end
        end

        file
      end
    end

    # do not let multiple processes get in each others way
    def lock_output
      if File === @io
        begin
          @io.flock File::LOCK_EX
          yield
        ensure
          @io.flock File::LOCK_UN
        end
      else
        yield
      end
    end
  end
end
