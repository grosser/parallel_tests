require 'parallel'
require 'parallel_tests/version'
require 'parallel_tests/grouper'
require 'parallel_tests/railtie' if defined? Rails::Railtie

module ParallelTests
  def self.determine_number_of_processes(count)
    [
      count,
      ENV['PARALLEL_TEST_PROCESSORS'],
      Parallel.processor_count
    ].detect{|c| not c.to_s.strip.empty? }.to_i
  end

  # copied from http://github.com/carlhuda/bundler Bundler::SharedHelpers#find_gemfile
  def self.bundler_enabled?
    return true if Object.const_defined?(:Bundler)

    previous = nil
    current = File.expand_path(Dir.pwd)

    until !File.directory?(current) || current == previous
      filename = File.join(current, "Gemfile")
      return true if File.exists?(filename)
      current, previous = File.expand_path("..", current), current
    end

    false
  end
end
