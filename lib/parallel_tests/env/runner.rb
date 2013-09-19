require 'open3'

module ParallelTests
  module Env
    class Runner < ParallelTests::Test::Runner
      class << self
        def name
          "Env"
        end

        def runtime_log
          'tmp/parallel_runtime_env.log'
        end

        def test_suffix
          "_{test,spec}.rb"
        end

        def run_tests(test_files, process_number, num_processes, options)
          require_list = test_files.map { |filename| %{"#{File.expand_path filename}"} }.join(" ")
          cmd = "#{executable} #{require_list}"
          execute_command(cmd, process_number, num_processes, options)
        end
      end
    end
  end
end