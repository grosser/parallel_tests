require 'parallel_tests/test/runner'

module ParallelTests
  module RSpec
    class Runner < ParallelTests::Test::Runner
      def self.run_tests(test_files, process_number, options)
        exe = executable # expensive, so we cache
        cmd = "#{exe} #{options[:test_options]} #{rspec_color}#{spec_opts(version)} #{test_files*' '}"
        execute_command(cmd, process_number, options)
      end

      def self.executable
        cmd = if ParallelTests.bundler_enabled?
          "bundle exec rspec"
        else
          "rspec" if system "rspec --version > /dev/null 2>&1"
        end
        cmd or raise("Can't find executable rspec")
      end

      def self.runtime_log
        'tmp/parallel_runtime_rspec.log'
      end

      def self.test_file_name
        "spec"
      end

      def self.test_suffix
        "_spec.rb"
      end

      private

      # so it can be stubbed....
      def self.run(cmd)
        `#{cmd}`
      end

      def self.rspec_color
        '--color --tty ' if $stdout.tty?
      end

      def self.spec_opts(rspec_version)
        options_file = ['.rspec_parallel', 'spec/parallel_spec.opts', 'spec/spec.opts'].detect{|f| File.file?(f) }
        return unless options_file
        "-O #{options_file}"
      end
    end
  end
end
