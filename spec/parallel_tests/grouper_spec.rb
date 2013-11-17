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
      expect(result).to match_array( [
        ["#{tmpdir}/a.feature", "#{tmpdir}/c.feature"],
        ["#{tmpdir}/b.feature"]
      ])
    end
  end

  describe :in_even_groups_by_size do
    let(:files_with_size){ {"1" => 1, "2" => 2, "3" => 3, "4" => 4, "5" => 5} }

    def call(num_groups)
      ParallelTests::Grouper.in_even_groups_by_size(files_with_size, num_groups)
    end

    it "groups 1 by 1 for same groups as size" do
      expect(call(5)).to eq [["5"], ["4"], ["3"], ["2"], ["1"]]
    end

    it "groups into even groups" do
      expect(call(2)).to eq [["1", "2", "5"], ["3", "4"]]
    end

    it "groups into a single group" do
      expect(call(1)).to eq [["1", "2", "3", "4", "5"]]
    end

    it "adds empty groups if there are more groups than feature files" do
      expect(call(6)).to eq [["5"], ["4"], ["3"], ["2"], ["1"], []]
    end
  end
end
