namespace :parallel do
  desc "update test databases by running db:test:prepare for each --> parallel:prepare[num_cpus]"
  task :prepare, :count do |t,args|
    require File.join(File.dirname(__FILE__), '..', 'lib', "parallel_tests")

    Parallel.in_processes(args[:count] ? args[:count].to_i : nil) do |i|
      puts "Preparing test database #{i + 1}"
      `export TEST_ENV_NUMBER=#{ParallelTests.test_env_number(i)} ; rake db:test:prepare`
    end
  end

  # Useful when dumping/resetting takes too long
  desc "update test databases by running db:mgrate for each --> parallel:migrate[num_cpus]"
  task :migrate, :count do |t,args|
    require File.join(File.dirname(__FILE__), '..', 'lib', "parallel_tests")

    Parallel.in_processes(args[:count] ? args[:count].to_i : nil) do |i|
      puts "Migrating test database #{i + 1}"
      `export TEST_ENV_NUMBER=#{ParallelTests.test_env_number(i)} ; rake db:migrate RAILS_ENV=test`
    end
  end

  ['test', 'spec', 'features'].each do |type|
    desc "run #{type} in parallel with parallel:#{type}[num_cpus]"
    task type, :count, :path_prefix, :options do |t,args|
      require File.join(File.dirname(__FILE__), '..', 'lib', "parallel_tests")
      count, prefix, options = ParallelTests.parse_rake_args(args)
      sh "#{File.join(File.dirname(__FILE__), '..', 'bin', 'parallel_test')} --type #{type} -n #{count} -p '#{prefix}' -r '#{RAILS_ROOT}' -o '#{options}'"
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
