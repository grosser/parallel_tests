require File.join(File.dirname(__FILE__), 'parallel_tests')

class ParallelSpecs < ParallelTests
  def self.run_tests(test_files, process_number, options)
    exe = executable # its expensive with bundler, so do not call it twice
    cmd = "#{color} #{exe} #{options} #{spec_opts(exe)} #{test_files*' '}"
    results = execute_command(cmd, process_number)
    return 'Aborted' if results[:exit_status] == 1 && results[:stdout] == ''
    results[:stdout]
  end

  def self.executable
    cmd = if File.file?("script/spec")
      "script/spec"
    elsif bundler_enabled?
      cmd = (run("bundle show rspec") =~ %r{/rspec-1[^/]+$} ? "spec" : "rspec")
      "bundle exec #{cmd}"
    else
      %w[spec rspec].detect{|cmd| system "#{cmd} --version > /dev/null 2>&1" }
    end
    cmd or raise("Can't find executables rspec or spec")
  end

  protected

  # so it can be stubbed....
  def self.run(cmd)
    `#{cmd}`
  end

  def self.spec_opts(executable)
    opts = ['spec/parallel_spec.opts', 'spec/spec.opts'].detect{|f| File.file?(f) }
    return unless opts
    if executable =~ /\brspec\b/
      # RSpec2 does not handle -O, so we inline the options
      File.read(opts).tr("\n", ' ')
    else
      "-O #{opts}"
    end
  end

  #display color when we are in a terminal
  def self.color
    ($stdout.tty? ? 'RSPEC_COLOR=1 ; export RSPEC_COLOR ;' : '')
  end

  def self.test_suffix
    "_spec.rb"
  end
end
