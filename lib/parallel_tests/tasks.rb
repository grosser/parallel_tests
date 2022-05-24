# frozen_string_literal: true
require 'rake'
require 'shellwords'

module ParallelTests
  module Tasks
    class << self
      def rails_env
        'test'
      end

      def load_lib
        $LOAD_PATH << File.expand_path('..', __dir__)
        require "parallel_tests"
      end

      def purge_before_load
        if Gem::Version.new(Rails.version) > Gem::Version.new('4.2.0')
          Rake::Task.task_defined?('db:purge') ? 'db:purge' : 'app:db:purge'
        end
      end

      def run_in_parallel(cmd, options = {})
        load_lib

        # Using the relative path to find the binary allow to run a specific version of it
        executable = File.expand_path('../../bin/parallel_test', __dir__)
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

        if system('/bin/bash', '-c', "#{activate_pipefail} 2>/dev/null")
          shell_command = "#{activate_pipefail} && (#{Shellwords.shelljoin(command)}) | #{remove_ignored_lines}"
          ['/bin/bash', '-c', shell_command]
        else
          command
        end
      end

      def suppress_schema_load_output(command)
        ParallelTests::Tasks.suppress_output(command, "^   ->\\|^-- ")
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
        if rails_7_or_greater?
          ActiveRecord.schema_format
        else
          ActiveRecord::Base.schema_format
        end
      end

      def schema_type_based_on_rails_version
        if rails_61_or_greater? || schema_format_based_on_rails_version == :ruby
          "schema"
        else
          "structure"
        end
      end

      private

      def rails_7_or_greater?
        Gem::Version.new(Rails.version) >= Gem::Version.new('7.0')
      end

      def rails_61_or_greater?
        Gem::Version.new(Rails.version) >= Gem::Version.new('6.1.0')
      end
    end
  end
end

namespace :parallel do
  desc "Setup test databases via db:setup --> parallel:setup[num_cpus]"
  task :setup, :count do |_, args|
    command = [$0, "db:setup", "RAILS_ENV=#{ParallelTests::Tasks.rails_env}"]
    ParallelTests::Tasks.run_in_parallel(ParallelTests::Tasks.suppress_schema_load_output(command), args)
  end

  desc "Create test databases via db:create --> parallel:create[num_cpus]"
  task :create, :count do |_, args|
    ParallelTests::Tasks.run_in_parallel(
      [$0, "db:create", "RAILS_ENV=#{ParallelTests::Tasks.rails_env}"],
      args
    )
  end

  desc "Drop test databases via db:drop --> parallel:drop[num_cpus]"
  task :drop, :count do |_, args|
    ParallelTests::Tasks.run_in_parallel(
      [
        $0,
        "db:drop",
        "RAILS_ENV=#{ParallelTests::Tasks.rails_env}",
        "DISABLE_DATABASE_ENVIRONMENT_CHECK=1"
      ],
      args
    )
  end

  desc "Update test databases by dumping and loading --> parallel:prepare[num_cpus]"
  task(:prepare, [:count]) do |_, args|
    ParallelTests::Tasks.check_for_pending_migrations

    if defined?(ActiveRecord) && [:ruby, :sql].include?(ParallelTests::Tasks.schema_format_based_on_rails_version)
      # fast: dump once, load in parallel
      type = ParallelTests::Tasks.schema_type_based_on_rails_version

      Rake::Task["db:#{type}:dump"].invoke

      # remove database connection to prevent "database is being accessed by other users"
      ActiveRecord::Base.remove_connection if ActiveRecord::Base.configurations.any?

      Rake::Task["parallel:load_#{type}"].invoke(args[:count])
    else
      # slow: dump and load in in serial
      args = args.to_hash.merge(non_parallel: true) # normal merge returns nil
      task_name = Rake::Task.task_defined?('db:test:prepare') ? 'db:test:prepare' : 'app:db:test:prepare'
      ParallelTests::Tasks.run_in_parallel([$0, task_name], args)
      next
    end
  end

  # when dumping/resetting takes too long
  desc "Update test databases via db:migrate --> parallel:migrate[num_cpus]"
  task :migrate, :count do |_, args|
    ParallelTests::Tasks.run_in_parallel(
      [$0, "db:migrate", "RAILS_ENV=#{ParallelTests::Tasks.rails_env}"],
      args
    )
  end

  desc "Rollback test databases via db:rollback --> parallel:rollback[num_cpus]"
  task :rollback, :count do |_, args|
    ParallelTests::Tasks.run_in_parallel(
      [$0, "db:rollback", "RAILS_ENV=#{ParallelTests::Tasks.rails_env}"],
      args
    )
  end

  # just load the schema (good for integration server <-> no development db)
  desc "Load dumped schema for test databases via db:schema:load --> parallel:load_schema[num_cpus]"
  task :load_schema, :count do |_, args|
    command = [
      $0,
      ParallelTests::Tasks.purge_before_load,
      "db:schema:load",
      "RAILS_ENV=#{ParallelTests::Tasks.rails_env}",
      "DISABLE_DATABASE_ENVIRONMENT_CHECK=1"
    ]
    ParallelTests::Tasks.run_in_parallel(ParallelTests::Tasks.suppress_schema_load_output(command), args)
  end

  # load the structure from the structure.sql file
  # (faster for rails < 6.1, deprecated after and only configured by `ActiveRecord::Base.schema_format`)
  desc "Load structure for test databases via db:schema:load --> parallel:load_structure[num_cpus]"
  task :load_structure, :count do |_, args|
    ParallelTests::Tasks.run_in_parallel(
      [
        $0,
        ParallelTests::Tasks.purge_before_load,
        "db:structure:load",
        "RAILS_ENV=#{ParallelTests::Tasks.rails_env}",
        "DISABLE_DATABASE_ENVIRONMENT_CHECK=1"
      ],
      args
    )
  end

  desc "Load the seed data from db/seeds.rb via db:seed --> parallel:seed[num_cpus]"
  task :seed, :count do |_, args|
    ParallelTests::Tasks.run_in_parallel(
      [
        $0,
        "db:seed",
        "RAILS_ENV=#{ParallelTests::Tasks.rails_env}"
      ],
      args
    )
  end

  desc "Launch given rake command in parallel"
  task :rake, :command, :count do |_, args|
    ParallelTests::Tasks.run_in_parallel(
      [$0, args.command, "RAILS_ENV=#{ParallelTests::Tasks.rails_env}"],
      args
    )
  end

  ['test', 'spec', 'features', 'features-spinach'].each do |type|
    desc "Run #{type} in parallel with parallel:#{type}[num_cpus]"
    task type, [:count, :pattern, :options, :pass_through] do |_t, args|
      ParallelTests::Tasks.check_for_pending_migrations
      ParallelTests::Tasks.load_lib

      count, pattern, options, pass_through = ParallelTests::Tasks.parse_args(args)
      test_framework = {
        'spec' => 'rspec',
        'test' => 'test',
        'features' => 'cucumber',
        'features-spinach' => 'spinach'
      }.fetch(type)

      type = 'features' if test_framework == 'spinach'
      # Using the relative path to find the binary allow to run a specific version of it
      executable = File.expand_path('../../bin/parallel_test', __dir__)

      command = [*ParallelTests.with_ruby_binary(executable), type, '--type', test_framework]
      command += ['-n', count] if count
      command += ['--pattern', pattern] if pattern
      command += ['--test-options', options] if options
      command << pass_through if pass_through

      abort unless system(*command) # allow to chain tasks e.g. rake parallel:spec parallel:features
    end
  end
end
