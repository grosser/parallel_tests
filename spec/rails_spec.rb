# frozen_string_literal: true
require 'fileutils'
require 'spec_helper'

describe 'rails' do
  let(:test_timeout) { 800 } # this can take very long on fresh bundle ...

  def run(command, options = {})
    result = IO.popen(options.fetch(:environment, {}), command, err: [:child, :out], &:read)
    raise "FAILED #{command}\n#{result}" if $?.success? == !!options[:fail]
    result
  end

  Dir["spec/fixtures/rails*"].each do |folder|
    rails = File.basename(folder)
    next if RUBY_VERSION >= "3.1.0" && rails < "rails70" # https://github.com/rails/rails/issues/43998
    next if RUBY_VERSION < "2.7.0" && rails >= "rails70"

    it "can create and run #{rails}" do
      skip 'rails fixtures are not set up for java' if RUBY_PLATFORM == "java"

      Dir.chdir("spec/fixtures/#{rails}") do
        Bundler.with_unbundled_env do
          # unset travis things
          ENV.delete("RAILS_ENV")
          ENV.delete("RACK_ENV")

          run ["bundle", "config", "--local", "path", "vendor/bundle"]
          run ["bundle", "install"]
          FileUtils.rm_f(Dir['db/*.sqlite3'])
          run ["bundle", "exec", "rake", "db:setup", "parallel:create"]
          # Also test the case where the DBs need to be dropped
          run ["bundle", "exec", "rake", "parallel:drop", "parallel:create"]
          run ["bundle", "exec", "rake", "parallel:prepare"]
          run ["bundle", "exec", "rails", "runner", "User.create"], environment: { 'RAILS_ENV' => 'test' } # pollute the db
          out = run ["bundle", "exec", "rake", "parallel:prepare", "parallel:test"]
          expect(out).to match(/ 2 (tests|runs)/)
        end
      end
    end
  end
end
