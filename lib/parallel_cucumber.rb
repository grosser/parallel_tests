require File.join(File.dirname(__FILE__), 'parallel_tests')

class ParallelCucumber < ParallelTests
  def self.run_tests(test_files, process_number, options)
    color = ($stdout.tty? ? 'AUTOTEST=1 ; export AUTOTEST ;' : '')#display color when we are in a terminal
    cmd = "#{color} #{executable} #{options} #{test_files*' '}"
    results = execute_command(cmd, process_number)
    return 'Aborted' if results[:exit_status] == 1 && results[:stdout] == ''
    results[:stdout]
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

  protected

  def self.test_suffix
    ".feature"
  end

  def self.line_is_result?(line)
    line =~ /^\d+ (steps|scenarios)/ || line_is_abort?(line)
  end

  def self.line_is_failure?(line)
    line =~ /^\d+ (steps|scenarios).*(\d{2,}|[1-9]) failed/ || line_is_abort?(line)
  end
end
