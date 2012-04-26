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
        ParallelTests::Grouper.by_steps(["#{dir}/a.feature", "#{dir}/b.feature", "#{dir}/c.feature"],2)
      end

      # testing inside mktmpdir is always green
      result.should =~ [
        ["#{tmpdir}/a.feature", "#{tmpdir}/c.feature"],
        ["#{tmpdir}/b.feature"]
      ]
    end
  end

  describe :group_features_by_steps do
    it "groups" do
      features_with_steps = {"10" => 1, "9" => 2, "8" => 3, "7" => 4, "6" => 5}
      ParallelTests::Grouper.group_features_by_steps(features_with_steps, 5).should == [["10"],["9"], ["8"], ["7"], ["6"]]
      ParallelTests::Grouper.group_features_by_steps(features_with_steps, 2).should == [["10", "8", "6"], ["9", "7"]]
      ParallelTests::Grouper.group_features_by_steps(features_with_steps, 1).should ==  [["10", "9", "8", "7", "6"]]
    end

    it "returns an empty groups if there are more groups than feature files" do
      features_with_steps = Hash["10", 1, "9", 2, "8", 3, "7", 4, "6", 5]
      ParallelTests::Grouper.group_features_by_steps(features_with_steps, 6).should == [["10"], ["9"], ["8"], ["7"], ["6"], []]
    end
  end
end
