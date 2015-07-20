require 'bundler/setup'
require 'bump/tasks'
require 'bundler/gem_tasks'

task :default do
  if RUBY_VERSION < "1.9.0"
    sh "rspec --tag ~fails_on_ruby_187 spec/"
  else
    sh "rspec spec/"
  end
end
