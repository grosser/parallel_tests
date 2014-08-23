$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
name = "parallel_tests"
require "#{name}/version"

Gem::Specification.new name, ParallelTests::VERSION do |s|
  s.summary = "Run Test::Unit / RSpec / Cucumber / Spinach in parallel"
  s.authors = ["Michael Grosser"]
  s.email = "michael@grosser.it"
  s.homepage = "http://github.com/grosser/#{name}"
  s.files = `git ls-files`.split("\n")
  s.license = "MIT"
  s.executables = ["calabash_android","parallel_spinach", "parallel_cucumber", "parallel_rspec", "parallel_test"]
  s.add_runtime_dependency "parallel"
end
