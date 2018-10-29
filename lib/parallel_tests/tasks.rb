require 'rake'

module ParallelTests
  module Tasks
    class << self
      def rails_env
        ENV['RAILS_ENV'] || 'test'
      end

      def load_lib
        $LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), '..'))
        require "parallel_tests"
      end

      def purge_before_load
        if Gem::Version.new(Rails.version) > Gem::Version.new('4.2.0')
          Rake::Task.task_defined?('db:purge') ? 'db:purge' : 'app:db:purge'
        end
      end

      def run_in_parallel(cmd, options={})
        load_lib
        count = " -n #{options[:count]}" unless options[:count].to_s.empty?
        # Using the relative path to find the binary allow to run a specific version of it
        executable = File.expand_path("../../../bin/parallel_test", __FILE__)
        command = "#{ParallelTests.with_ruby_binary(Shellwords.escape(executable))} --exec '#{cmd}'#{count}#{' --non-parallel' if options[:non_parallel]}"
        abort unless system(command)
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
      # - do not use ' since run_in_parallel uses them to quote stuff
      # - simple system "set -o pipefail" returns nil even though set -o pipefail exists with 0
      def suppress_output(command, ignore_regex)
        activate_pipefail = "set -o pipefail"
        remove_ignored_lines = %Q{(grep -v "#{ignore_regex}" || test 1)}

        if File.executable?('/bin/bash') && system('/bin/bash', '-c', "#{activate_pipefail} 2>/dev/null && test 1")
          # We need to shell escape single quotes (' becomes '"'"') because
          # run_in_parallel wraps command in single quotes
          %Q{/bin/bash -c '"'"'#{activate_pipefail} && (#{command}) | #{remove_ignored_lines}'"'"'}
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
        num_processes = count.to_i unless count.to_s.empty?
        pattern = args.shift
        options = args.shift
        pass_through = args.shift

        [num_processes, pattern.to_s, options.to_s, pass_through.to_s]
      end
    end
  end
end

namespace :parallel do
  desc "Setup test databases via db:setup --> parallel:setup[num_cpus]"
  task :setup, :count do |_,args|
    command = "rake db:setup RAILS_ENV=#{ParallelTests::Tasks.rails_env}"
    ParallelTests::Tasks.run_in_parallel(ParallelTests::Tasks.suppress_schema_load_output(command), args)
  end

  desc "Create test databases via db:create --> parallel:create[num_cpus]"
  task :create, :count do |_,args|
    ParallelTests::Tasks.run_in_parallel("rake db:create RAILS_ENV=#{ParallelTests::Tasks.rails_env}", args)
  end

  desc "Drop test databases via db:drop --> parallel:drop[num_cpus]"
  task :drop, :count do |_,args|
    ParallelTests::Tasks.run_in_parallel("rake db:drop RAILS_ENV=#{ParallelTests::Tasks.rails_env} DISABLE_DATABASE_ENVIRONMENT_CHECK=1", args)
  end

  desc "Update test databases by dumping and loading --> parallel:prepare[num_cpus]"
  task(:prepare, [:count]) do |_,args|
    ParallelTests::Tasks.check_for_pending_migrations
    if defined?(ActiveRecord) && ActiveRecord::Base.schema_format == :ruby
      # dump then load in parallel
      Rake::Task['db:schema:dump'].invoke
      Rake::Task['parallel:load_schema'].invoke(args[:count])
    else
      # there is no separate dump / load for schema_format :sql -> do it safe and slow
      args = args.to_hash.merge(:non_parallel => true) # normal merge returns nil
      taskname = Rake::Task.task_defined?('db:test:prepare') ? 'db:test:prepare' : 'app:db:test:prepare'
      ParallelTests::Tasks.run_in_parallel("rake #{taskname}", args)
    end
  end

  # when dumping/resetting takes too long
  desc "Update test databases via db:migrate --> parallel:migrate[num_cpus]"
  task :migrate, :count do |_,args|
    ParallelTests::Tasks.run_in_parallel("rake db:migrate RAILS_ENV=#{ParallelTests::Tasks.rails_env}", args)
  end

  desc "Rollback test databases via db:rollback --> parallel:rollback[num_cpus]"
  task :rollback, :count do |_,args|
    ParallelTests::Tasks.run_in_parallel("rake db:rollback RAILS_ENV=#{ParallelTests::Tasks.rails_env}", args)
  end

  # just load the schema (good for integration server <-> no development db)
  desc "Load dumped schema for test databases via db:schema:load --> parallel:load_schema[num_cpus]"
  task :load_schema, :count do |_,args|
    command = "rake #{ParallelTests::Tasks.purge_before_load} db:schema:load RAILS_ENV=#{ParallelTests::Tasks.rails_env} DISABLE_DATABASE_ENVIRONMENT_CHECK=1"
    ParallelTests::Tasks.run_in_parallel(ParallelTests::Tasks.suppress_schema_load_output(command), args)
  end

  # load the structure from the structure.sql file
  desc "Load structure for test databases via db:structure:load --> parallel:load_structure[num_cpus]"
  task :load_structure, :count do |_,args|
    ParallelTests::Tasks.run_in_parallel("rake #{ParallelTests::Tasks.purge_before_load} db:structure:load RAILS_ENV=#{ParallelTests::Tasks.rails_env} DISABLE_DATABASE_ENVIRONMENT_CHECK=1", args)
  end

  desc "Load the seed data from db/seeds.rb via db:seed --> parallel:seed[num_cpus]"
  task :seed, :count do |_,args|
    ParallelTests::Tasks.run_in_parallel("rake db:seed RAILS_ENV=#{ParallelTests::Tasks.rails_env}", args)
  end

  desc "Launch given rake command in parallel"
  task :rake, :command, :count do |_, args|
    ParallelTests::Tasks.run_in_parallel("RAILS_ENV=#{ParallelTests::Tasks.rails_env} rake #{args.command}", args)
  end

  ['test', 'spec', 'features', 'features-spinach'].each do |type|
    desc "Run #{type} in parallel with parallel:#{type}[num_cpus]"
    task type, [:count, :pattern, :options, :pass_through] do |t, args|
      ParallelTests::Tasks.check_for_pending_migrations
      ParallelTests::Tasks.load_lib

      count, pattern, options, pass_through = ParallelTests::Tasks.parse_args(args)
      test_framework = {
        'spec' => 'rspec',
        'test' => 'test',
        'features' => 'cucumber',
        'features-spinach' => 'spinach',
      }[type]

      if test_framework == 'spinach'
        type = 'features'
      end
      # Using the relative path to find the binary allow to run a specific version of it
      executable = File.join(File.dirname(__FILE__), '..', '..', 'bin', 'parallel_test')

      command = "#{ParallelTests.with_ruby_binary(Shellwords.escape(executable))} #{type} --type #{test_framework} " \
        "-n #{count} "                     \
        "--pattern '#{pattern}' "          \
        "--test-options '#{options}' "     \
        "#{pass_through}"
      abort unless system(command) # allow to chain tasks e.g. rake parallel:spec parallel:features
    end
  end
end
