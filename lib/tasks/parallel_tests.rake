namespace :parallel do
  def run_in_parallel(cmd, options)
    count = (options[:count] ? options[:count].to_i : nil)
    executable = File.join(File.dirname(__FILE__), '..', '..', 'bin', 'parallel_test')
    command = "#{executable} --exec '#{cmd}' -n #{count}"
    abort unless system(command)
  end

  desc "create test databases by running db:create for each test db --> parallel:create[num_cpus]"
  task :create, :count do |t,args|
    run_in_parallel('rake db:create RAILS_ENV=test', args)
  end

  desc "update test databases by running db:test:prepare for each test db --> parallel:prepare[num_cpus]"
  task :prepare, :count do |t,args|
    run_in_parallel('rake db:test:prepare', args)
  end

  # when dumping/resetting takes too long
  desc "update test databases by running db:mgrate for each test db --> parallel:migrate[num_cpus]"
  task :migrate, :count do |t,args|
    run_in_parallel('rake db:migrate RAILS_ENV=test', args)
  end

  # Do not want a development db on integration server.
  # and always dump a complete schema ?
  desc "load dumped schema for each test db --> parallel:load_schema[num_cpus]"
  task :load_schema, :count do |t,args|
    run_in_parallel('rake db:schema:load RAILS_ENV=test', args)
  end

  ['test', 'spec', 'features'].each do |type|
    desc "run #{type} in parallel with parallel:#{type}[num_cpus]"
    task type, :count, :path_prefix, :options do |t,args|
      $LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), '..'))
      require "parallel_tests"
      count, prefix, options = ParallelTests.parse_rake_args(args)
      executable = File.join(File.dirname(__FILE__), '..', '..', 'bin', 'parallel_test')
      command = "#{executable} --type #{type} -n #{count} -p '#{prefix}' -r '#{RAILS_ROOT}' -o '#{options}'"
      abort unless system(command) # allow to chain tasks e.g. rake parallel:spec parallel:features
    end
  end
end

#backwards compatability
#spec:parallel:prepare
#spec:parallel
#test:parallel
namespace :spec do
  namespace :parallel do
    task :prepare, :count do |t,args|
      $stderr.puts "WARNING -- Deprecated!  use parallel:prepare"
      Rake::Task['parallel:prepare'].invoke(args[:count])
    end
  end

  task :parallel, :count, :path_prefix do |t,args|
    $stderr.puts "WARNING -- Deprecated! use parallel:spec"
    Rake::Task['parallel:spec'].invoke(args[:count], args[:path_prefix])
  end
end

namespace :test do
  task :parallel, :count, :path_prefix do |t,args|
    $stderr.puts "WARNING -- Deprecated! use parallel:test"
    Rake::Task['parallel:test'].invoke(args[:count], args[:path_prefix])
  end
end
