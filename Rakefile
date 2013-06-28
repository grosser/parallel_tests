require 'bump/tasks'
require 'bundler/gem_tasks'


task :default do
  if ENV['RUBY_VERSION'] && ENV['RUBY_VERSION'] < "1.9.0"
    sh "rspec --tag ~filter_for_ruby_187 spec/"
  else
    sh "rspec spec/"
  end
end
