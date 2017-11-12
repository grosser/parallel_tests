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
elsif defined?(MiniTest::Unit) # Minitest 4
  MiniTest::Unit.class_eval do
    alias_method :_run_suite_without_runtime_log, :_run_suite
    def _run_suite(*args)
      ParallelTests::Test::RuntimeLogger.log_test_run(args.first) do
        _run_suite_without_runtime_log(*args)
      end
    end

    alias_method :_run_suites_without_runtime_log, :_run_suites
    def _run_suites(*args)
      result = _run_suites_without_runtime_log(*args)
      ParallelTests::Test::RuntimeLogger.unique_log
      result
    end
  end
else # Test::Unit
  require 'test/unit/testsuite'
  class ::Test::Unit::TestSuite
    alias_method :run_without_timing, :run

    def run(result, &block)
      test = tests.first

      if test.is_a? ::Test::Unit::TestSuite # all tests ?
        run_without_timing(result, &block)
        ParallelTests::Test::RuntimeLogger.unique_log
      else
        ParallelTests::Test::RuntimeLogger.log_test_run(test.class) do
          run_without_timing(result, &block)
        end
      end
    end
  end
end
