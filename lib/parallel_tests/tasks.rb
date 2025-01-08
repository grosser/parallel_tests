# frozen_string_literal: true
require 'shellwords'
require_relative 'tasks/helpers.rb'

namespace :parallel do
  desc "Setup test databases via db:setup --> parallel:setup[num_cpus]"
  task :setup, :count do |_, args|
    command = [$0, "db:setup", "RAILS_ENV=#{ParallelTests::Tasks::Helpers.rails_env}"]
    ParallelTests::Tasks::Helpers.
      run_in_parallel(ParallelTests::Tasks::Helpers.suppress_schema_load_output(command), args)
  end

  ParallelTests::Tasks::Helpers.for_each_database do |name|
    task_name = 'create'
    task_name += ":#{name}" if name
    desc "Create test#{" #{name}" if name} database via db:#{task_name} --> parallel:#{task_name}[num_cpus]"
    task task_name.to_sym, :count do |_, args|
      ParallelTests::Tasks::Helpers.run_in_parallel(
        [$0, "db:#{task_name}", "RAILS_ENV=#{ParallelTests::Tasks::Helpers.rails_env}"],
        args
      )
    end
  end

  ParallelTests::Tasks::Helpers.for_each_database do |name|
    task_name = 'drop'
    task_name += ":#{name}" if name
    desc "Drop test#{" #{name}" if name} database via db:#{task_name} --> parallel:#{task_name}[num_cpus]"
    task task_name.to_sym, :count do |_, args|
      ParallelTests::Tasks::Helpers.run_in_parallel(
        [
          $0,
          "db:#{task_name}",
          "RAILS_ENV=#{ParallelTests::Tasks::Helpers.rails_env}",
          "DISABLE_DATABASE_ENVIRONMENT_CHECK=1"
        ],
        args
      )
    end
  end

  desc "Update test databases by dumping and loading --> parallel:prepare[num_cpus]"
  task(:prepare, [:count]) do |_, args|
    ParallelTests::Tasks::Helpers.check_for_pending_migrations

    if defined?(ActiveRecord) && [:ruby, :sql].include?(ParallelTests::Tasks::Helpers.schema_format_based_on_rails_version)
      # fast: dump once, load in parallel
      type = ParallelTests::Tasks::Helpers.schema_type_based_on_rails_version

      Rake::Task["db:#{type}:dump"].invoke

      # remove database connection to prevent "database is being accessed by other users"
      ActiveRecord::Base.remove_connection if ActiveRecord::Base.configurations.any?

      Rake::Task["parallel:load_#{type}"].invoke(args[:count])
    else
      # slow: dump and load in in serial
      args = args.to_hash.merge(non_parallel: true) # normal merge returns nil
      task_name = Rake::Task.task_defined?('db:test:prepare') ? 'db:test:prepare' : 'app:db:test:prepare'
      ParallelTests::Tasks::Helpers.run_in_parallel([$0, task_name], args)
      next
    end
  end

  # when dumping/resetting takes too long
  ParallelTests::Tasks::Helpers.for_each_database do |name|
    task_name = 'migrate'
    task_name += ":#{name}" if name
    desc "Update test#{" #{name}" if name} database via db:#{task_name} --> parallel:#{task_name}[num_cpus]"
    task task_name.to_sym, :count do |_, args|
      ParallelTests::Tasks::Helpers.run_in_parallel(
        [$0, "db:#{task_name}", "RAILS_ENV=#{ParallelTests::Tasks::Helpers.rails_env}"],
        args
      )
    end
  end

  desc "Rollback test databases via db:rollback --> parallel:rollback[num_cpus]"
  task :rollback, :count do |_, args|
    ParallelTests::Tasks::Helpers.run_in_parallel(
      [$0, "db:rollback", "RAILS_ENV=#{ParallelTests::Tasks::Helpers.rails_env}"],
      args
    )
  end

  # just load the schema (good for integration server <-> no development db)
  ParallelTests::Tasks::Helpers.for_each_database do |name|
    rails_task = 'db:schema:load'
    rails_task += ":#{name}" if name

    task_name = 'load_schema'
    task_name += ":#{name}" if name

    desc "Load dumped schema for test#{" #{name}" if name} database via #{rails_task} --> parallel:#{task_name}[num_cpus]"
    task task_name.to_sym, :count do |_, args|
      command = [
        $0,
        ParallelTests::Tasks::Helpers.purge_before_load,
        rails_task,
        "RAILS_ENV=#{ParallelTests::Tasks::Helpers.rails_env}",
        "DISABLE_DATABASE_ENVIRONMENT_CHECK=1"
      ]
      ParallelTests::Tasks::Helpers.run_in_parallel(ParallelTests::Tasks::Helpers.suppress_schema_load_output(command), args)
    end
  end

  # load the structure from the structure.sql file
  # (faster for rails < 6.1, deprecated after and only configured by `ActiveRecord::Base.schema_format`)
  desc "Load structure for test databases via db:schema:load --> parallel:load_structure[num_cpus]"
  task :load_structure, :count do |_, args|
    ParallelTests::Tasks::Helpers.run_in_parallel(
      [
        $0,
        ParallelTests::Tasks::Helpers.purge_before_load,
        "db:structure:load",
        "RAILS_ENV=#{ParallelTests::Tasks::Helpers.rails_env}",
        "DISABLE_DATABASE_ENVIRONMENT_CHECK=1"
      ],
      args
    )
  end

  desc "Load the seed data from db/seeds.rb via db:seed --> parallel:seed[num_cpus]"
  task :seed, :count do |_, args|
    ParallelTests::Tasks::Helpers.run_in_parallel(
      [
        $0,
        "db:seed",
        "RAILS_ENV=#{ParallelTests::Tasks::Helpers.rails_env}"
      ],
      args
    )
  end

  desc "Launch given rake command in parallel"
  task :rake, :command, :count do |_, args|
    ParallelTests::Tasks::Helpers.run_in_parallel(
      [$0, args.command, "RAILS_ENV=#{ParallelTests::Tasks::Helpers.rails_env}"],
      args
    )
  end

  ['test', 'spec', 'features', 'features-spinach'].each do |type|
    desc "Run #{type} in parallel with parallel:#{type}[num_cpus]"
    task type, [:count, :pattern, :options, :pass_through] do |_t, args|
      ParallelTests::Tasks::Helpers.check_for_pending_migrations
      ParallelTests::Tasks::Helpers.load_lib
      command = ParallelTests::Tasks::Helpers.build_run_command(type, args)

      abort unless system(*command) # allow to chain tasks e.g. rake parallel:spec parallel:features
    end
  end
end
