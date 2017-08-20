require "parallel_tests/test/runner"

module ParallelTests
  module RSpec
    class Runner < ParallelTests::Test::Runner
      DEV_NULL = (WINDOWS ? "NUL" : "/dev/null")
      NAME = 'RSpec'

      class << self
        def run_tests(test_files, process_number, num_processes, options)
          exe = executable # expensive, so we cache
          cmd = [exe, options[:test_options], color, spec_opts, *test_files].compact.join(" ")
          execute_command(cmd, process_number, num_processes, options)
        end

        def determine_executable
          cmd = case
          when File.exist?("bin/rspec")
            "bin/rspec"
          when ParallelTests.bundler_enabled?
            cmd = (run("bundle show rspec-core") =~ %r{Could not find gem.*} ? "spec" : "rspec")
            "bundle exec #{cmd}"
          else
            %w[spec rspec].detect{|cmd| system "#{cmd} --version > #{DEV_NULL} 2>&1" }
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

        def line_is_result?(line)
          line =~ /\d+ examples?, \d+ failures?/
        end

        # remove old seed and add new seed
        # --seed 1234
        # --order rand
        # --order rand:1234
        # --order random:1234
        def command_with_seed(cmd, seed)
          clean = cmd.sub(/\s--(seed\s+\d+|order\s+rand(om)?(:\d+)?)\b/, '')
          "#{clean} --seed #{seed}"
        end


        private

        # so it can be stubbed....
        def run(cmd)
          `#{cmd}`
        end

        def color
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
