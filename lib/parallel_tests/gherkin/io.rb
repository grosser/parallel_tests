require 'tempfile'
require 'parallel_tests'

module ParallelTests
  module Gherkin
    module Io

      def prepare_io(path_or_io)
        if path_or_io.respond_to?(:write)
          path_or_io
        else # its a path
          temp_filename = File.join(Dir.tmpdir, "#{File.basename(path_or_io)}-lock")
          temp_lock = File.open(temp_filename, File::CREAT|File::APPEND)
          if temp_lock.flock(File::LOCK_EX|File::LOCK_NB)
            File.open(path_or_io, 'w').close # clean out the file

            at_exit do
              unless temp_lock.closed?
                temp_lock.close
                temp_lock.unlink
              end
            end
          end
          file = File.open(path_or_io, 'a')

          at_exit do
            unless file.closed?
              file.flush
              File.unlink(temp_filename)
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
