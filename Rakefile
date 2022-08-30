# frozen_string_literal: true
require 'bundler/setup'
require 'bump/tasks'
require 'bundler/gem_tasks'

# update all versions so bundling does not fail on CI
Bump.replace_in_default = Dir["spec/fixtures/rails*/Gemfile.lock"]

task default: [:spec, :rubocop]

task :spec do
  sh "rspec spec/"
end

desc "Run rubocop"
task :rubocop do
  sh "rubocop --parallel"
end

desc "bundle all gemfiles [EXTRA=]"
task :bundle_all do
  extra = ENV.fetch("EXTRA", nil) || "install"

  gemfiles = (["Gemfile"] + Dir["spec/fixtures/rails*/Gemfile"])
  raise if gemfiles.size < 3

  gemfiles.each do |gemfile|
    Bundler.with_unbundled_env do
      sh "GEMFILE=#{gemfile} bundle #{extra}"
    end
  end
end
