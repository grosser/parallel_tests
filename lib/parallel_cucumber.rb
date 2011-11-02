require 'parallel_tests'

class ParallelCucumber < ParallelTests
  def self.run_tests(test_files, process_number, options)
    color = ($stdout.tty? ? 'AUTOTEST=1 ; export AUTOTEST ;' : '')#display color when we are in a terminal
    runtime_logging = " --format ParallelCucumber::RuntimeLogger --out #{runtime_log}"
    cmd = "#{color} #{executable}"
    cmd << runtime_logging if File.directory?(File.dirname(runtime_log))
    cmd << " #{options[:test_options]} #{test_files*' '}"
    execute_command(cmd, process_number, options)
  end

  def self.executable
    if bundler_enabled?
      "bundle exec cucumber"
    elsif File.file?("script/cucumber")
      "script/cucumber"
    else
      "cucumber"
    end
  end

  def self.runtime_log
    'tmp/parallel_runtime_cucumber.log'
  end

  protected

  def self.test_suffix
    ".feature"
  end

  def self.line_is_result?(line)
    line =~ /^\d+ (steps|scenarios)/
  end
end
