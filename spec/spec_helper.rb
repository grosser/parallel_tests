# ---- requirements
$LOAD_PATH << File.expand_path("../lib", File.dirname(__FILE__))
require 'rubygems'

FAKE_RAILS_ROOT = '/tmp/pspecs/fixtures'

require 'parallel_specs'
require 'parallel_cucumber'

def size_of(group)
  group.inject(0) { |sum, test| sum += File.stat(test).size }
end

def test_tests_in_groups(klass, folder, suffix)
  test_root = "#{FAKE_RAILS_ROOT}/#{folder}"

  describe :tests_in_groups do
    before :all do
      system "rm -rf #{FAKE_RAILS_ROOT}; mkdir -p #{test_root}/temp"

      @files = [0,1,2,3,4,5,6,7].map do |i|
        size = 99
        file = "#{test_root}/temp/x#{i}#{suffix}"
        File.open(file, 'w') { |f| f.puts 'x' * size }
        file
      end

      @log = "#{FAKE_RAILS_ROOT}/tmp/parallel_profile.log"
      `mkdir #{File.dirname(@log)}`
      `rm -f #{@log}`
    end

    it "finds all tests" do
      found = klass.tests_in_groups(test_root, 1)
      all = [ Dir["#{test_root}/**/*#{suffix}"] ]
      (found.flatten - all.flatten).should == []
    end

    it "partitions them into groups by equal size" do
      groups = klass.tests_in_groups(test_root, 2)
      groups.map{|g| size_of(g)}.should == [400, 400]
    end

    it 'should partition correctly with a group size of 4' do
      groups = klass.tests_in_groups(test_root, 4)
      groups.map{|g| size_of(g)}.should == [200, 200, 200, 200]
    end

    it 'should partition correctly with an uneven group size' do
      groups = klass.tests_in_groups(test_root, 3)
      groups.map{|g| size_of(g)}.should =~ [300, 300, 200]
    end

    it "partitions by runtime when runtime-data is available" do
      File.open(@log,'w') do |f|
        @files[1..-1].each{|file| f.puts "#{file}:#{@files.index(file)}"}
        f.puts "#{@files[0]}:10"
      end

      groups = klass.tests_in_groups(test_root, 2)
      groups.size.should == 2
      # 10 + 5 + 3 + 1 = 19
      groups[0].should == [@files[0],@files[5],@files[3],@files[1]]
      # 7 + 6 + 4 + 2 = 19
      groups[1].should == [@files[7],@files[6],@files[4],@files[2]]
    end
  end
end