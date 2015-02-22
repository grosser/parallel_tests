require 'parallel_tests'
require 'parallel_tests/test/runner'

module ParallelTests
  module Test
    class RuntimeLogger
      @@previous_log_cleaned = false

      class << self
        # ensure folder exists + clean out previous log
        # this will happen in multiple processes, but should be roughly at the same time
        # so there should be no log message lost
        def prepare
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
          delta = "%.2f" % (end_time.to_f-start_time.to_f)
          filename = class_directory(test.class) + class_to_filename(test.class) + ".rb"
          "#{filename}:#{delta}"
        end

        # Note: this is a best guess at conventional test directory structure, and may need
        # tweaking / post-processing to match correctly for any given project
        def class_directory(suspect)
          result = "test/"

          if defined?(Rails)
            result += case suspect.superclass.name
            when "ActionDispatch::IntegrationTest"
              "integration/"
            when "ActionDispatch::PerformanceTest"
              "performance/"
            when "ActionController::TestCase"
              "functional/"
            when "ActionView::TestCase"
              "unit/helpers/"
            else
              "unit/"
            end
          end
          result
        end

        # based on https://github.com/grosser/single_test/blob/master/lib/single_test.rb#L117
        def class_to_filename(suspect)
          word = suspect.to_s.dup
          return word unless word.match /^[A-Z]/ and not word.match %r{/[a-z]}

          word.gsub!(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
          word.gsub!(/([a-z\d])([A-Z])/, '\1_\2')
          word.gsub!(/\:\:/, '/')
          word.tr!("-", "_")
          word.downcase!
          word
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
  alias :run_without_timing :run unless defined? @@timing_installed

  def run(result, &progress_block)
    ParallelTests::Test::RuntimeLogger.prepare
    first_test = self.tests.first
    start_time = ParallelTests.now
    run_without_timing(result, &progress_block)
    end_time = ParallelTests.now
    ParallelTests::Test::RuntimeLogger.log(first_test, start_time, end_time)
  end

  @@timing_installed = true
end
