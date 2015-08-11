require 'spec_helper'

describe 'rails' do
  let(:test_timeout) { 240 } # this can take very long on fresh bundle ...

  def sh(command, options={})
    result = `#{command}`
    raise "FAILED #{command}\n#{result}" if $?.success? == !!options[:fail]
    result
  end

  ["rails32", "rails42"].each do |rails|
    it "can create and run" do
      skip if RUBY_PLATFORM == "java"
      if rails == 'rails32'
        ruby_2_2_2_or_newer = Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.2.2')
        skip 'rails 3.2 does not work on ruby >= 2.2.2' if ruby_2_2_2_or_newer
      end

      Dir.chdir("spec/fixtures/#{rails}") do
        Bundler.with_clean_env do
          # unset travis things
          ENV.delete("RAILS_ENV")
          ENV.delete("RACK_ENV")

          sh "bundle --local --path vendor/bundle"
          sh "rm -rf db/*.sqlite3"
          sh "bundle exec rake db:setup parallel:create 2>&1"
          sh "bundle exec rake parallel:prepare"
          sh "export RAILS_ENV=test && bundle exec rails runner User.create" # pollute the db
          out = sh "bundle exec rake parallel:prepare parallel:test"
          expect(out).to match(/ 2 (tests|runs)/)
        end
      end
    end
  end
end
