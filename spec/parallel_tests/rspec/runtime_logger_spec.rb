require 'spec_helper'

describe ParallelTests::RSpec::RuntimeLogger do
  before do
    # pretend we run in parallel or the logger will log nothing
    ENV['TEST_ENV_NUMBER'] = ''
    @clean_output = %r{^spec/foo.rb:[-\.e\d]+$}m
  end

  def log_for_a_file(options={})
    Tempfile.open('xxx') do |temp|
      temp.close
      f = File.open(temp.path,'w')
      logger = if block_given?
        yield(f)
      else
        ParallelTests::RSpec::RuntimeLogger.new(f)
      end

      example = double(:file_path => "#{Dir.pwd}/spec/foo.rb")
      unless ParallelTests::RSpec::RuntimeLogger::RSPEC_2
        example = double(:group => example)
      end

      logger.example_group_started example
      logger.example_group_finished example

      logger.start_dump

      #f.close
      return File.read(f.path)
    end
  end

  it "logs runtime with relative paths" do
    expect(log_for_a_file).to match(@clean_output)
  end

  it "does not log if we do not run in parallel" do
    ENV.delete 'TEST_ENV_NUMBER'
    expect(log_for_a_file).to eq("")
  end

  it "appends to a given file" do
    result = log_for_a_file do |f|
      f.write 'FooBar'
      ParallelTests::RSpec::RuntimeLogger.new(f)
    end
    expect(result).to include('FooBar')
    expect(result).to include('foo.rb')
  end

  it "overwrites a given path" do
    result = log_for_a_file do |f|
      f.write 'FooBar'
      ParallelTests::RSpec::RuntimeLogger.new(f.path)
    end
    expect(result).not_to include('FooBar')
    expect(result).to include('foo.rb')
  end

  context "integration" do
    around do |example|
      Dir.mktmpdir do |dir|
        Dir.chdir(dir, &example)
      end
    end

    def write(file, content)
      FileUtils.mkdir_p(File.dirname(file))
      File.open(file, 'w') { |f| f.write content }
    end

    it "logs shared examples into the running files" do
      write "spec/spec_helper.rb", <<-RUBY
        shared_examples "foo" do
          it "is slow" do
            sleep 0.5
          end
        end
      RUBY

      ["a", "b"].each do |letter|
        write "spec/#{letter}_spec.rb", <<-RUBY
          require 'spec_helper'
          describe 'xxx' do
            it_behaves_like "foo"
          end
        RUBY
      end

      system("TEST_ENV_NUMBER=1 rspec spec -I #{Bundler.root.join("lib")} --format ParallelTests::RSpec::RuntimeLogger --out runtime.log 2>&1") || raise("nope")

      result = File.read("runtime.log")
      expect(result).to match(%r{^spec/a_spec.rb:0.5})
      expect(result).to match(%r{^spec/b_spec.rb:0.5})
      expect(result).not_to include "spec_helper"
    end

    it "logs multiple describe blocks" do
      write "spec/a_spec.rb", <<-RUBY
        describe "xxx" do
          it "is slow" do
            sleep 0.5
          end
        end

        describe "yyy" do
          it "is slow" do
            sleep 0.5
          end

          describe "yep" do
            it "is slow" do
              sleep 0.5
            end
          end
        end
      RUBY

      system("TEST_ENV_NUMBER=1 rspec spec -I #{Bundler.root.join("lib")} --format ParallelTests::RSpec::RuntimeLogger --out runtime.log 2>&1") || raise("nope")

      result = File.read("runtime.log")
      expect(result).to include "a_spec.rb:1.5"
    end
  end
end
