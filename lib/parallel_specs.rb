require File.join(File.dirname(__FILE__), 'parallel_tests')

class ParallelSpecs < ParallelTests
  def self.run_tests(test_files, process_number)
    spec_opts = File.file?('spec/parallel_spec.opts') ? 'spec/parallel_spec.opts' : 'spec/spec.opts'
    color = ($stdout.tty? ? 'export RSPEC_COLOR=1 ;' : '')#display color when we are in a terminal
    cmd = "export RAILS_ENV=test ; export TEST_ENV_NUMBER=#{test_env_number(process_number)} ; #{color} #{executable} -O #{spec_opts} #{test_files*' '}"
    execute_command(cmd)
  end

  def self.executable
    File.exist?("script/spec") ? "script/spec" : "spec"
  end

  protected

  def self.find_tests(root)
    Dir["#{root}**/**/*_spec.rb"]
  end
end
