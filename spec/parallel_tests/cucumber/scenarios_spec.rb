require 'tempfile'
require 'parallel_tests/cucumber/scenarios'

module ParallelTests
  module Cucumber
    describe Scenarios do
      describe '.all' do
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
            scenarios = Scenarios.all([feature_file.path])
            scenarios.should eq %W(#{feature_file.path}:3 #{feature_file.path}:6)
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
            scenarios = Scenarios.all([feature_file.path], :ignore_tag_pattern => '@ignore, @wip')
            scenarios.should eq %W(#{feature_file.path}:7)
          end
        end
      end
    end
  end
end
