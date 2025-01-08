# frozen_string_literal: true
require 'rake'

module ParallelTests
  module Tasks
    module Helpers
      class << self
        def rails_env
          'test'
        end

        def load_lib
          $LOAD_PATH << File.expand_path('../..', __dir__)
          require "parallel_tests"
        end

        def purge_before_load
          if ActiveRecord.version > Gem::Version.new('4.2.0')
            Rake::Task.task_defined?('db:purge') ? 'db:purge' : 'app:db:purge'
          end
        end

        def run_in_parallel(cmd, options = {})
          load_lib

          # Using the relative path to find the binary allow to run a specific version of it
          executable = File.expand_path('../../../bin/parallel_test', __dir__)
          command = ParallelTests.with_ruby_binary(executable)
          command += ['--exec', Shellwords.join(cmd)]
          command += ['-n', options[:count]] unless options[:count].to_s.empty?
          command << '--non-parallel' if options[:non_parallel]

          abort unless system(*command)
        end

        # this is a crazy-complex solution for a very simple problem:
        # removing certain lines from the output without changing the exit-status
        # normally I'd not do this, but it has been lots of fun and a great learning experience :)
        #
        # - sed does not support | without -r
        # - grep changes 0 exitstatus to 1 if nothing matches
        # - sed changes 1 exitstatus to 0
        # - pipefail makes pipe fail with exitstatus of first failed command
        # - pipefail is not supported in (zsh)
        # - defining a new rake task like silence_schema would force users to load parallel_tests in test env
        # - simple system "set -o pipefail" returns nil even though set -o pipefail exists with 0
        def suppress_output(command, ignore_regex)
          activate_pipefail = "set -o pipefail"
          remove_ignored_lines = %{(grep -v #{Shellwords.escape(ignore_regex)} || true)}

          # remove nil values (ex: #purge_before_load returns nil)
          command.compact!

          if system('/bin/bash', '-c', "#{activate_pipefail} 2>/dev/null")
            shell_command = "#{activate_pipefail} && (#{Shellwords.shelljoin(command)}) | #{remove_ignored_lines}"
            ['/bin/bash', '-c', shell_command]
          else
            command
          end
        end

        def suppress_schema_load_output(command)
          suppress_output(command, "^   ->\\|^-- ")
        end

        def check_for_pending_migrations
          ["db:abort_if_pending_migrations", "app:db:abort_if_pending_migrations"].each do |abort_migrations|
            if Rake::Task.task_defined?(abort_migrations)
              Rake::Task[abort_migrations].invoke
              break
            end
          end
        end

        # parallel:spec[:count, :pattern, :options, :pass_through]
        def parse_args(args)
          # order as given by user
          args = [args[:count], args[:pattern], args[:options], args[:pass_through]]

          # count given or empty ?
          # parallel:spec[2,models,options]
          # parallel:spec[,models,options]
          count = args.shift if args.first.to_s =~ /^\d*$/
          num_processes = (count.to_s.empty? ? nil : Integer(count))
          pattern = args.shift
          options = args.shift
          pass_through = args.shift

          [num_processes, pattern, options, pass_through]
        end

        def schema_format_based_on_rails_version
          if active_record_7_or_greater?
            ActiveRecord.schema_format
          else
            ActiveRecord::Base.schema_format
          end
        end

        def schema_type_based_on_rails_version
          if active_record_61_or_greater? || schema_format_based_on_rails_version == :ruby
            "schema"
          else
            "structure"
          end
        end

        def build_run_command(type, args)
          count, pattern, options, pass_through = parse_args(args)
          test_framework = {
            'spec' => 'rspec',
            'test' => 'test',
            'features' => 'cucumber',
            'features-spinach' => 'spinach'
          }.fetch(type)

          type = 'features' if test_framework == 'spinach'

          # Using the relative path to find the binary allow to run a specific version of it
          executable = File.expand_path('../../../bin/parallel_test', __dir__)
          executable = ParallelTests.with_ruby_binary(executable)

          command = [*executable, type, '--type', test_framework]
          command += ['-n', count.to_s] if count
          command += ['--pattern', pattern] if pattern
          command += ['--test-options', options] if options
          command += Shellwords.shellsplit pass_through if pass_through
          command
        end

        def configured_databases
          return [] unless defined?(ActiveRecord) && active_record_61_or_greater?

          @@configured_databases ||= ActiveRecord::Tasks::DatabaseTasks.setup_initial_database_yaml
        end

        def for_each_database(&block)
          # Use nil to represent all databases
          block&.call(nil)

          # skip if not rails or old rails version
          return if !defined?(ActiveRecord::Tasks::DatabaseTasks) || !ActiveRecord::Tasks::DatabaseTasks.respond_to?(:for_each)

          ActiveRecord::Tasks::DatabaseTasks.for_each(configured_databases) do |name|
            block&.call(name)
          end
        end

        private

        def active_record_7_or_greater?
          ActiveRecord.version >= Gem::Version.new('7.0')
        end

        def active_record_61_or_greater?
          ActiveRecord.version >= Gem::Version.new('6.1.0')
        end
      end
    end
  end
end
