name = "parallel_tests"
require "./lib/#{name}/version"

Gem::Specification.new name, ParallelTests::VERSION do |s|
  s.summary = "Run Test::Unit / RSpec / Cucumber / Spinach in parallel"
  s.authors = ["Michael Grosser"]
  s.email = "michael@grosser.it"
  s.homepage = "http://github.com/grosser/#{name}"
  s.files = Dir["{lib,bin}/**/*"] + ["Readme.md"]
  s.license = "MIT"
  s.executables = ["parallel_spinach", "parallel_cucumber", "parallel_rspec", "parallel_test"]
  s.add_runtime_dependency "parallel"
  s.required_ruby_version = '>= 1.9.3'
end
