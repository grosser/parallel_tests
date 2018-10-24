require 'parallel_tests'
require 'parallel_tests/test/runner'

module ParallelTests
  module Test
    class RuntimeLogger
      @@prepared = false

      class << self
        def log_test_run(test)
          prepare

          result = nil
          time = ParallelTests.delta { result = yield }
          log(test, time)

          result
        end

        def unique_log
          with_locked_log do |logfile|
            separator = "\n"
            groups = logfile.read.split(separator).map { |line| line.split(":") }.group_by(&:first)
            lines = groups.map do |file, times|
              time = "%.2f" % times.map(&:last).map(&:to_f).inject(:+)
              "#{file}:#{time}"
            end
            logfile.rewind
            logfile.write(lines.join(separator) + separator)
            logfile.truncate(logfile.pos)
          end
        end

        private

        def with_locked_log
          File.open(logfile, File::RDWR|File::CREAT) do |logfile|
            logfile.flock(File::LOCK_EX)
            yield logfile
          end
        end

        # ensure folder exists + clean out previous log
        # this will happen in multiple processes, but should be roughly at the same time
        # so there should be no log message lost
        def prepare
          return if @@prepared
          @@prepared = true
          FileUtils.mkdir_p(File.dirname(logfile))
          File.write(logfile, '')
        end

        def log(test, time)
          return unless message = message(test, time)
          with_locked_log do |logfile|
            logfile.seek(0, IO::SEEK_END)
            logfile.puts message
          end
        end

        def message(test, delta)
          return unless method = test.public_instance_methods(true).detect { |method| method =~ /^test_/ }
          filename = test.instance_method(method).source_location.first.sub("#{Dir.pwd}/", "")
          "#{filename}:#{delta}"
        end

        def logfile
          ParallelTests::Test::Runner.runtime_log
        end
      end
    end
  end
end

if defined?(Minitest::Runnable) # Minitest 5
  class << Minitest::Runnable
    prepend(Module.new do
      def run(*)
        ParallelTests::Test::RuntimeLogger.log_test_run(self) do
          super
        end
      end
    end)
  end

  class << Minitest
    prepend(Module.new do
      def run(*args)
        result = super
        ParallelTests::Test::RuntimeLogger.unique_log
        result
      end
    end)
  end
end
