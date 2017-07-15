require 'bundler/setup'
require 'tempfile'
require 'tmpdir'
require 'timeout'

require 'parallel_tests'
require 'parallel_tests/test/runtime_logger'
require 'parallel_tests/rspec/runtime_logger'
require 'parallel_tests/rspec/summary_logger'

String.class_eval do
  def strip_heredoc
    gsub(/^#{self[/^\s*/]}/, '')
  end
end

OutputLogger = Struct.new(:output) do
  attr_reader :flock, :flush
  def puts(s=nil)
    self.output << "#{s}\n"
  end
  def print(s=nil)
    self.output << "#{s}"
  end
end

module SpecHelper
  def mocked_process
    StringIO.new
  end

  def size_of(group)
    group.map { |test| File.stat(test).size }.inject(:+)
  end

  def use_temporary_directory(&block)
    Dir.mktmpdir { |dir| Dir.chdir(dir, &block) }
  end

  def with_files(files)
    Dir.mktmpdir do |root|
      files.each do |file|
        parent = "#{root}/#{File.dirname(file)}"
        `mkdir -p #{parent}` unless File.exist?(parent)
        `touch #{root}/#{file}`
      end
      yield root
    end
  end

  def should_run_with(regex)
    expect(ParallelTests::Test::Runner).to receive(:execute_command) do |a, b, c, d|
      expect(a).to match(regex)
    end
  end

  def should_not_run_with(regex)
    expect(ParallelTests::Test::Runner).to receive(:execute_command) do |a, b, c, d|
      expect(a).to_not match(regex)
    end
  end
end

module SharedExamples
  def test_tests_in_groups(klass, suffix)
    describe ".tests_in_groups" do
      let(:log) { klass.runtime_log }
      let(:test_root) { "temp" }

      around { |test| use_temporary_directory(&test) }

      before do
        FileUtils.mkdir test_root
        @files = [0,1,2,3,4,5,6,7].map { |i| "#{test_root}/x#{i}#{suffix}" }
        @files.each { |file| File.write(file, 'x' * 100) }
        FileUtils.mkdir_p File.dirname(log)
      end

      def setup_runtime_log
        File.open(log,'w') do |f|
          @files[1..-1].each{|file| f.puts "#{file}:#{@files.index(file)}"}
          f.puts "#{@files[0]}:10"
        end
      end

      it "groups when given an array of files" do
        list_of_files = Dir["#{test_root}/**/*#{suffix}"]
        result = list_of_files.dup
        klass.send(:sort_by_filesize, result)
        expect(result).to match_array(list_of_files.map{ |file| [file, File.stat(file).size]})
      end

      it "finds all tests" do
        found = klass.tests_in_groups([test_root], 1)
        all = [ Dir["#{test_root}/**/*#{suffix}"] ]
        expect(found.flatten - all.flatten).to eq([])
      end

      it "partitions them into groups by equal size" do
        groups = klass.tests_in_groups([test_root], 2)
        expect(groups.map { |g| size_of(g) }).to eq([400, 400])
      end

      it 'should partition correctly with a group size of 4' do
        groups = klass.tests_in_groups([test_root], 4)
        expect(groups.map { |g| size_of(g) }).to eq([200, 200, 200, 200])
      end

      it 'should partition correctly with an uneven group size' do
        groups = klass.tests_in_groups([test_root], 3)
        expect(groups.map {|g| size_of(g) }).to match_array([300, 300, 200])
      end

      it "partitions by runtime when runtime-data is available" do
        allow(klass).to receive(:puts)
        setup_runtime_log

        groups = klass.tests_in_groups([test_root], 2)
        expect(groups.size).to eq(2)
        # 10 + 1 + 3 + 5 = 19
        expect(groups[0]).to eq([@files[0],@files[1],@files[3],@files[5]])
        # 2 + 4 + 6 + 7 = 19
        expect(groups[1]).to eq([@files[2],@files[4],@files[6],@files[7]])
      end

      it 'partitions from custom runtime-data location' do
        allow(klass).to receive(:puts)
        log.replace('tmp/custom_runtime.log')
        setup_runtime_log

        groups = klass.tests_in_groups([test_root], 2, runtime_log: log)
        expect(groups.size).to eq(2)
        # 10 + 1 + 3 + 5 = 19
        expect(groups[0]).to eq([@files[0],@files[1],@files[3],@files[5]])
        # 2 + 4 + 6 + 7 = 19
        expect(groups[1]).to eq([@files[2],@files[4],@files[6],@files[7]])
      end

      it "alpha-sorts partitions when runtime-data is available" do
        allow(klass).to receive(:puts)
        setup_runtime_log

        groups = klass.tests_in_groups([test_root], 2)
        expect(groups.size).to eq(2)

        expect(groups[0]).to eq(groups[0].sort)
        expect(groups[1]).to eq(groups[1].sort)
      end

      it "partitions by round-robin when not sorting" do
        files = ["file1.rb", "file2.rb", "file3.rb", "file4.rb"]
        expect(klass).to receive(:find_tests).and_return(files)
        groups = klass.tests_in_groups(files, 2, :group_by => :found).sort
        expect(groups[0]).to eq(["file1.rb", "file3.rb"])
        expect(groups[1]).to eq(["file2.rb", "file4.rb"])
      end

      it "alpha-sorts partitions when not sorting by runtime" do
        files = %w[q w e r t y u i o p a s d f g h j k l z x c v b n m]
        expect(klass).to receive(:find_tests).and_return(files)
        groups = klass.tests_in_groups(files, 2, :group_by => :found).sort
        expect(groups[0]).to eq(groups[0].sort)
        expect(groups[1]).to eq(groups[1].sort)
      end
    end
  end
end

RSpec.configure do |config|
  config.filter_run :focus => true
  config.run_all_when_everything_filtered = true
  config.include SpecHelper
  config.extend SharedExamples

  config.raise_errors_for_deprecations!

  # sometimes stuff hangs -> do not hang everything
  config.include(Module.new {def test_timeout;30;end })
  config.around do |example|
    Timeout.timeout(test_timeout, &example)
  end

  config.after do
    ENV.delete "PARALLEL_TEST_GROUPS"
    ENV.delete "PARALLEL_TEST_PROCESSORS"
    ENV.delete "PARALLEL_TESTS_EXECUTABLE"
    ENV.delete "TEST_ENV_NUMBER"
    ENV.delete "RAILS_ENV"
  end
end
