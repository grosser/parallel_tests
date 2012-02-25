$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
name = "parallel_tests"
require "#{name}/version"

Gem::Specification.new name, ParallelTests::VERSION do |s|
  s.summary = "Run tests / specs / features in parallel"
  s.authors = ["Michael Grosser"]
  s.email = "michael@grosser.it"
  s.homepage = "http://github.com/grosser/#{name}"
  s.files = `git ls-files`.split("\n")
  s.license = "MIT"
  s.executables = ["parallel_cucumber", "parallel_spec", "parallel_test"]
  s.add_runtime_dependency "parallel"
end
