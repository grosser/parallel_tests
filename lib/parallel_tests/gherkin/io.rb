require 'parallel_tests'

module ParallelTests
  module Gherkin
    module Io

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
end
