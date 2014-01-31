require "parallel_tests/test/runner"

module ParallelTests
  module RSpec
    class Runner < ParallelTests::Test::Runner
      NAME = 'RSpec'

      class << self
        def run_tests(test_files, process_number, num_processes, options)
          exe = executable # expensive, so we cache
          version = (exe =~ /\brspec\b/ ? 2 : 1)
          cmd = [exe, options[:test_options], (rspec_2_color if version == 2), spec_opts, *test_files].compact.join(" ")
          options = options.merge(:env => rspec_1_color) if version == 1
          execute_command(cmd, process_number, num_processes, options)
        end

        def determine_executable
          cmd = case
          when File.exists?("bin/rspec")
            "bin/rspec"
          when File.file?("script/spec")
            "script/spec"
          when ParallelTests.bundler_enabled?
            cmd = (run("bundle show rspec-core") =~ %r{Could not find gem.*} ? "spec" : "rspec")
            "bundle exec #{cmd}"
          else
            %w[spec rspec].detect{|cmd| system "#{cmd} --version > /dev/null 2>&1" }
          end

          cmd or raise("Can't find executables rspec or spec")
        end

        def runtime_log
          'tmp/parallel_runtime_rspec.log'
        end

        def test_file_name
          "spec"
        end

        def test_suffix
          /_spec\.rb$/
        end

        private

        # so it can be stubbed....
        def run(cmd)
          `#{cmd}`
        end

        def rspec_1_color
          if $stdout.tty?
            {'RSPEC_COLOR' => "1"}
          else
            {}
          end
        end

        def rspec_2_color
          '--color --tty' if $stdout.tty?
        end

        def spec_opts
          options_file = ['.rspec_parallel', 'spec/parallel_spec.opts', 'spec/spec.opts'].detect{|f| File.file?(f) }
          return unless options_file
          "-O #{options_file}"
        end
      end
    end
  end
end
