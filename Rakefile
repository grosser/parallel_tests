task :default => :spec
require 'spec/rake/spectask'
Spec::Rake::SpecTask.new {|t| t.spec_opts = ['--color --backtrace']}

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name     = "parallel_tests"
    gem.summary  = "Run tests / specs / features in parallel"
    gem.email    = "grosser.michael@gmail.com"
    gem.homepage = "http://github.com/grosser/#{gem.name}"
    gem.authors  = "Michael Grosser"
    gem.add_dependency "parallel"
  end

  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler, or one of its dependencies, is not available. Install it with: sudo gem install jeweler"
end
