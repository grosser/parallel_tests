namespace :parallel do
  def run_in_parallel(cmd, options)
    count = "-n #{options[:count]}" if options[:count]
    executable = File.join(File.dirname(__FILE__), '..', '..', 'bin', 'parallel_test')
    command = "#{executable} --exec '#{cmd}' #{count} #{'--non-parallel' if options[:non_parallel]}"
    abort unless system(command)
  end

  desc "create test databases via db:create --> parallel:create[num_cpus]"
  task :create, :count do |t,args|
    run_in_parallel('rake db:create RAILS_ENV=test', args)
  end

  desc "drop test databases via db:drop --> parallel:drop[num_cpus]"
  task :drop, :count do |t,args|
    run_in_parallel('rake db:drop RAILS_ENV=test', args)
  end

  desc "update test databases by dumping and loading --> parallel:prepare[num_cpus]"
  task(:prepare, [:count] => 'db:abort_if_pending_migrations') do |t,args|
    if defined?(ActiveRecord) && ActiveRecord::Base.schema_format == :ruby
      # dump then load in parallel
      Rake::Task['db:schema:dump'].invoke
      Rake::Task['parallel:load_schema'].invoke(args[:count])
    else
      # there is no separate dump / load for schema_format :sql -> do it safe and slow
      args = args.to_hash.merge(:non_parallel => true) # normal merge returns nil
      run_in_parallel('rake db:test:prepare --trace', args)
    end
  end

  # when dumping/resetting takes too long
  desc "update test databases via db:migrate --> parallel:migrate[num_cpus]"
  task :migrate, :count do |t,args|
    run_in_parallel('rake db:migrate RAILS_ENV=test', args)
  end

  # just load the schema (good for integration server <-> no development db)
  desc "load dumped schema for test databases via db:schema:load --> parallel:load_schema[num_cpus]"
  task :load_schema, :count do |t,args|
    run_in_parallel('rake db:test:load', args)
  end

  ['test', 'spec', 'features'].each do |type|
    desc "run #{type} in parallel with parallel:#{type}[num_cpus]"
    task type, [:count, :pattern, :options] => 'db:abort_if_pending_migrations' do |t,args|
      $LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), '..'))
      require "parallel_tests"
      count, pattern, options = ParallelTests.parse_rake_args(args)
      test_framework = {
        'spec' => 'rspec',
        'test' => 'test',
        'features' => 'cucumber'
      }[type]
      executable = File.join(File.dirname(__FILE__), '..', '..', 'bin', 'parallel_test')
      command = "#{executable} #{type} --type #{test_framework} -n #{count} -p '#{pattern}' -o '#{options}'"
      abort unless system(command) # allow to chain tasks e.g. rake parallel:spec parallel:features
    end
  end
end
