task :default => :spec
require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = '--backtrace --color'
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name     = "parallel_tests"
    gem.summary  = "Run tests / specs / features in parallel"
    gem.email    = "grosser.michael@gmail.com"
    gem.homepage = "http://github.com/grosser/#{gem.name}"
    gem.authors  = "Michael Grosser"
  end

  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler, or one of its dependencies, is not available. Install it with: sudo gem install jeweler"
end
