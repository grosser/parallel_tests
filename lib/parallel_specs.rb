require File.join(File.dirname(__FILE__), 'parallel_tests')

class ParallelSpecs < ParallelTests
  def self.run_tests(test_files, process_number, options)
    exe = executable # expensive, so we cache
    version = (exe =~ /\brspec\b/ ? 2 : 1)
    cmd = "#{rspec_1_color if version == 1}#{exe} #{options[:test_options]} #{rspec_2_color if version == 2}#{spec_opts(version)} #{test_files*' '}"
    execute_command(cmd, process_number, options)
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

  def self.runtime_log
    'tmp/parallel_profile.log'
  end

  protected

  # so it can be stubbed....
  def self.run(cmd)
    `#{cmd}`
  end

  def self.rspec_1_color
    'RSPEC_COLOR=1 ; export RSPEC_COLOR ;' if $stdout.tty?
  end

  def self.rspec_2_color
    '--tty ' if $stdout.tty?
  end

  def self.spec_opts(rspec_version)
    options_file = ['spec/parallel_spec.opts', 'spec/spec.opts'].detect{|f| File.file?(f) }
    return unless options_file
    if rspec_version == 2
      # does not handle -O, so we inline the options
      File.read(options_file).tr("\n", ' ')
    else
      "-O #{options_file}"
    end
  end

  def self.test_suffix
    "_spec.rb"
  end
end
