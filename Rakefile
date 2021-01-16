require 'bundler/setup'
require 'bump/tasks'
require 'bundler/gem_tasks'

task default: [:spec, :rubocop]

task :spec do
  sh "rspec spec/"
end

desc "Run rubocop"
task :rubocop do
  sh "rubocop --parallel"
end
