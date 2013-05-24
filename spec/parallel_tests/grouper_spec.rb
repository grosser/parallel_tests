require 'spec_helper'
require 'parallel_tests/grouper'
require 'tmpdir'

describe ParallelTests::Grouper do
  describe :by_steps do
    def write(file, content)
      File.open(file,'w'){|f| f.write content }
    end

    it "sorts features by steps" do
      tmpdir = nil
      result = Dir.mktmpdir do |dir|
        tmpdir = dir
        write("#{dir}/a.feature", "Feature: xxx\n  Scenario: xxx\n    Given something")
        write("#{dir}/b.feature", "Feature: xxx\n  Scenario: xxx\n    Given something\n  Scenario: yyy\n    Given something")
        write("#{dir}/c.feature", "Feature: xxx\n  Scenario: xxx\n    Given something")
        ParallelTests::Grouper.by_steps(["#{dir}/a.feature", "#{dir}/b.feature", "#{dir}/c.feature"], 2, {})
      end

      # testing inside mktmpdir is always green
      result.should =~ [
        ["#{tmpdir}/a.feature", "#{tmpdir}/c.feature"],
        ["#{tmpdir}/b.feature"]
      ]
    end
  end

  describe :in_even_groups_by_size do
    let(:files_with_size){ {"1" => 1, "2" => 2, "3" => 3, "4" => 4, "5" => 5} }

    def call(num_groups)
      ParallelTests::Grouper.in_even_groups_by_size(files_with_size, num_groups)
    end

    it "groups 1 by 1 for same groups as size" do
      call(5).should == [["5"], ["4"], ["3"], ["2"], ["1"]]
    end

    it "groups into even groups" do
      call(2).should ==  [["1", "2", "5"], ["3", "4"]]
    end

    it "groups into a single group" do
      call(1).should == [["1", "2", "3", "4", "5"]]
    end

    it "adds empty groups if there are more groups than feature files" do
      call(6).should == [["5"], ["4"], ["3"], ["2"], ["1"], []]
    end
  end

  describe :by_scenario do
    let(:feature_file) do
      Tempfile.new('grouper.feature').tap do |feature|
        feature.write <<-EOS
          Feature: Grouping by scenario

            Scenario: First
              Given I do nothing

            Scenario: Second
              Given I don't do anything
        EOS
        feature.rewind
      end
    end

    it 'splits a feature into individual scenarios' do
      groups = ParallelTests::Grouper.by_scenario([feature_file.path])
      groups.should eq %W(#{feature_file.path}:3 #{feature_file.path}:6)
    end
  end
end
