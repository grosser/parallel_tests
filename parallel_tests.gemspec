# frozen_string_literal: true
name = "parallel_tests"
require_relative "lib/#{name}/version"

Gem::Specification.new name, ParallelTests::VERSION do |s|
  s.summary = "Run Test::Unit / RSpec / Cucumber / Spinach in parallel"
  s.authors = ["Michael Grosser"]
  s.email = "michael@grosser.it"
  s.homepage = "https://github.com/grosser/#{name}"
  s.metadata = {
    "bug_tracker_uri" => "https://github.com/grosser/#{name}/issues",
    "changelog_uri" => "https://github.com/grosser/#{name}/blob/v#{s.version}/CHANGELOG.md",
    "documentation_uri" => "https://github.com/grosser/#{name}/blob/v#{s.version}/Readme.md",
    "source_code_uri" => "https://github.com/grosser/#{name}/tree/v#{s.version}",
    "wiki_uri" => "https://github.com/grosser/#{name}/wiki"
  }



  s.files = Dir["{lib,bin}/**/*"] + ["Readme.md"]
  s.license = "MIT"
  s.executables = ["parallel_spinach", "parallel_cucumber", "parallel_rspec", "parallel_test"]
  s.add_runtime_dependency "parallel"
  s.required_ruby_version = '>= 3.0.0'
end
