require 'spec_helper'

describe 'rails' do
  def sh(command, fail: false)
    result = Bundler.with_clean_env { `#{command}` }
    raise "FAILED #{command}\n#{result}" if $?.success? == fail
    result
  end

  ["rails32"].each do |rails|
    it "can create and run" do
      Dir.chdir("spec/fixtures/#{rails}") do
        sh "bundle --local --deployment --path vendor/bundle"
        sh "rm -rf db/*.sqlite3"
        sh "bundle exec rake db:setup parallel:create 2>&1"
        sh "bundle exec rake parallel:prepare"
        sh "RAILS_ENV=test bundle exec rails runner User.create" # pollute the db
        out = sh "bundle exec rake parallel:prepare parallel:test"
        expect(out).to include "0 skips, 2 tests"
      end
    end
  end
end
