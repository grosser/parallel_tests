require File.join(File.dirname(__FILE__), 'parallel_tests')

class ParallelSpecs < ParallelTests
  def self.run_tests(test_files, process_number, options)
    spec_opts = ['spec/parallel_spec.opts', 'spec/spec.opts'].detect{|f| File.file?(f) }
    spec_opts = (spec_opts ? "-O #{spec_opts}" : nil)
    color = ($stdout.tty? ? 'RSPEC_COLOR=1 ; export RSPEC_COLOR ;' : '')#display color when we are in a terminal
    cmd = "RAILS_ENV=test ; export RAILS_ENV ; #{color} #{executable} #{options} #{spec_opts} #{test_files*' '}"
    execute_command(cmd, process_number)
  end

  def self.executable
    if File.file?(".bundle/environment.rb")
      "bundle exec spec"
    elsif File.file?("script/spec")
      "script/spec"
    else
      "spec"
    end
  end

  protected

  def self.find_tests(root)
    Dir["#{root}**/**/*_spec.rb"]
  end
end
