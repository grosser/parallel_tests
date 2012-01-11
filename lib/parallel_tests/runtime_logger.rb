class ParallelTests::RuntimeLogger
  @@has_started = false

  def self.log(test, start_time, end_time)
    return if test.is_a? Test::Unit::TestSuite  # don't log for suites-of-suites

    if !@@has_started # make empty log file 
      File.open(ParallelTests.runtime_log, 'w') do end
      @@has_started = true
    end

    File.open(ParallelTests.runtime_log, 'a') do |output|
      begin
        output.flock File::LOCK_EX
        output.puts(self.message(test, start_time, end_time))
      ensure
        output.flock File::LOCK_UN
      end
    end
  end

  def self.message(test, start_time, end_time)
    delta="%.2f" % (end_time.to_f-start_time.to_f)
    filename=class_directory(test.class) + class_to_filename(test.class) + ".rb"
    message="#{filename}:#{delta}"
  end

  # Note: this is a best guess at conventional test directory structure, and may need
  # tweaking / post-processing to match correctly for any given project
  def self.class_directory(suspect)
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
  def self.class_to_filename(suspect)
    word = suspect.to_s.dup
    return word unless word.match /^[A-Z]/ and not word.match %r{/[a-z]}

    word.gsub!(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
    word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
    word.gsub!(/\:\:/,'/')
    word.tr!("-", "_")
    word.downcase!
    word
  end

end

require 'test/unit/testsuite'
class Test::Unit::TestSuite

  alias :run_without_timing :run unless defined? @@timing_installed

  def run(result, &progress_block)
    start_time=Time.now
    run_without_timing(result, &progress_block)
    end_time=Time.now
    ParallelTests::RuntimeLogger.log(self.tests.first, start_time, end_time)
  end
  @@timing_installed = true

end
