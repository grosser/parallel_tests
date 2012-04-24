require 'parallel_tests/grouper'

describe ParallelTests::Grouper do
  describe :by_steps do
    it "returns proper groups" do
      features_with_steps = Hash["10", 1, "9", 2, "8", 3, "7", 4, "6", 5]
      ParallelTests::Grouper.by_steps(features_with_steps, 5).should == [["10"],["9"], ["8"], ["7"], ["6"]]
      ParallelTests::Grouper.by_steps(features_with_steps, 2).should == [["10", "8", "6"], ["9", "7"]]
      ParallelTests::Grouper.by_steps(features_with_steps, 1).should ==  [["10", "9", "8", "7", "6"]]
    end
    it "returns [] if there are more groups than feature files" do
      features_with_steps = Hash["10", 1, "9", 2, "8", 3, "7", 4, "6", 5]
      ParallelTests::Grouper.by_steps(features_with_steps, 6).should == [["10"], ["9"], ["8"], ["7"], ["6"], []]
    end
  end
end