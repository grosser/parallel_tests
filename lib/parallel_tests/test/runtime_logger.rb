require 'parallel_tests'
require 'parallel_tests/test/runner'

module ParallelTests
  module Test
    class RuntimeLogger
      @@prepared = false

      class << self
        # ensure folder exists + clean out previous log
        # this will happen in multiple processes, but should be roughly at the same time
        # so there should be no log message lost
        def prepare
          return if @@prepared
          @@prepared = true
          FileUtils.mkdir_p(File.dirname(logfile))
          File.write(logfile, '')
        end

        def log(test, start_time, end_time)
          return if test.is_a? ::Test::Unit::TestSuite # don't log for suites-of-suites

          locked_appending_to(logfile) do |file|
            file.puts(message(test, start_time, end_time))
          end
        end

        private

        def message(test, start_time, end_time)
          delta = "%.2f" % (end_time.to_f - start_time.to_f)
          method = test.public_methods(true).first
          filename = test.method(method).source_location.first.sub("#{Dir.pwd}/", "")
          "#{filename}:#{delta}"
        end

        def locked_appending_to(file)
          File.open(file, 'a') do |f|
            begin
              f.flock File::LOCK_EX
              yield f
            ensure
              f.flock File::LOCK_UN
            end
          end
        end

        def logfile
          ParallelTests::Test::Runner.runtime_log
        end
      end
    end
  end
end

require 'test/unit/testsuite'
class ::Test::Unit::TestSuite
  alias_method :run_without_timing, :run

  def run(result, &block)
    ParallelTests::Test::RuntimeLogger.prepare
    first_test = tests.first
    start_time = ParallelTests.now
    run_without_timing(result, &block)
    end_time = ParallelTests.now
    ParallelTests::Test::RuntimeLogger.log(first_test, start_time, end_time)
  end
end
