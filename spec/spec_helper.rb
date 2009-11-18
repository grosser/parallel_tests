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

      @files = [1,2,3,4,5,6,7,8].map do |i|
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
      groups.size.should == 2
      size_of(groups[0]).should == 400
      size_of(groups[1]).should == 400
    end

    it 'should partition correctly with a group size of 4' do
      groups = klass.tests_in_groups(test_root, 4)
      groups.size.should == 4
      size_of(groups[0]).should == 200
      size_of(groups[1]).should == 200
      size_of(groups[2]).should == 200
      size_of(groups[3]).should == 200
    end

    it 'should partition correctly with an uneven group size' do
      groups = klass.tests_in_groups(test_root, 3)
      groups.size.should == 3
      size_of(groups[0]).should == 300
      size_of(groups[1]).should == 300
      size_of(groups[2]).should == 200
    end

    it "partitions by runtime when runtime-data is available" do
      File.open(@log,'w') do |f|
        @files[1..-1].each{|file| f.puts "#{file}:2"}
        f.puts "#{@files[0]}:8"
      end

      groups = klass.tests_in_groups(test_root, 2)
      groups.size.should == 2
      groups[0].should == [@files[0],@files[1],@files[2]]
      groups[1].should == [@files[3],@files[4],@files[5],@files[6],@files[7]]
    end
  end
end