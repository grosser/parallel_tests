# frozen_string_literal: true
require 'spec_helper'

describe 'rails' do
  let(:test_timeout) { 800 } # this can take very long on fresh bundle ...

  def sh(command, options = {})
    result = ''
    IO.popen(options.fetch(:environment, {}), command, err: [:child, :out]) do |io|
      result = io.read
    end
    raise "FAILED #{command}\n#{result}" if $?.success? == !!options[:fail]
    result
  end

  Dir["spec/fixtures/rails*"].each do |folder|
    rails = File.basename(folder)
    it "can create and run #{rails}" do
      skip 'rails fixtures are not set up for java' if RUBY_PLATFORM == "java"

      Dir.chdir("spec/fixtures/#{rails}") do
        Bundler.with_unbundled_env do
          # unset travis things
          ENV.delete("RAILS_ENV")
          ENV.delete("RACK_ENV")

          sh "bundle config --local path vendor/bundle"
          sh "bundle install"
          sh "rm -rf db/*.sqlite3"
          sh "bundle exec rake db:setup parallel:create --trace 2>&1"
          # Also test the case where the DBs need to be dropped
          sh "bundle exec rake parallel:drop parallel:create"
          sh "bundle exec rake parallel:prepare"
          sh "bundle exec rails runner User.create", environment: { 'RAILS_ENV' => 'test' } # pollute the db
          out = sh "bundle exec rake parallel:prepare parallel:test"
          expect(out).to match(/ 2 (tests|runs)/)
        end
      end
    end
  end
end
