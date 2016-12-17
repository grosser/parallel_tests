require 'tempfile'
require 'parallel_tests/cucumber/scenarios'

describe ParallelTests::Cucumber::Scenarios do
  context 'by default' do
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

    it 'returns all the scenarios' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path])
      expect(scenarios).to eq %W(#{feature_file.path}:3 #{feature_file.path}:6)
    end
  end

  context 'with tags' do
    let(:feature_file) do
      Tempfile.new('grouper.feature').tap do |feature|
        feature.write <<-EOS
          Feature: Grouping by scenario

            @wip
            Scenario: First
              Given I do nothing

            Scenario: Second
              Given I don't do anything

            @ignore
            Scenario: Third
              Given I am ignored
        EOS
        feature.rewind
      end
    end

    it 'ignores those scenarios' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :ignore_tag_pattern => '@ignore, @wip')
      expect(scenarios).to eq %W(#{feature_file.path}:7)
    end

    it 'return scenarios with tag' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :test_options => '-t @wip')
      expect(scenarios).to eq %W(#{feature_file.path}:4)
    end

    it 'return scenarios with negative tag' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :test_options => '-t @ignore,~@wip') # @ignore or not @wip
      expect(scenarios).to eq %W(#{feature_file.path}:7 #{feature_file.path}:11)
    end
  end
end
