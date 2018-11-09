require 'tempfile'
require 'parallel_tests/cucumber/scenarios'

describe ParallelTests::Cucumber::Scenarios do

  let(:feature_file) do
    Tempfile.new('grouper.feature').tap do |feature|
      feature.write <<-EOS
          Feature: Grouping by scenario

            Scenario: First
              Given I do nothing

            Scenario: Second
              Given I don't do anything

            Scenario Outline: Third
              Given I don't do anything
            Examples:
              | param   |
              | value 1 |
              | value 2 |
      EOS
      feature.rewind
    end
  end


  context 'by default' do
    it 'returns all the scenarios' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path])
      expect(scenarios).to eq %W(#{feature_file.path}:3 #{feature_file.path}:6 #{feature_file.path}:13 #{feature_file.path}:14)
    end
  end

  context 'with line numbers' do
    it 'only returns scenarios that match the provided lines' do
      scenarios = ParallelTests::Cucumber::Scenarios.all(["#{feature_file.path}:6:14"])
      expect(scenarios).to eq %W(#{feature_file.path}:6 #{feature_file.path}:14)
    end
  end

  context 'with tags' do
    let(:feature_file) do
      Tempfile.new('grouper.feature').tap do |feature|
        feature.write <<-EOS
          @colours
          Feature: Grouping by scenario

            @black
            Scenario: Black
              Given I am black

            @white
            Scenario: White
              Given I am blue

            @black @white
            Scenario: Gray
              Given I am Gray

            @red
            Scenario Outline: Red
              Give I am <colour>
              @blue
              Examples:
                | colour  |
                | magenta |
                | fuschia |

              @green
              Examples:
                | colour |
                | yellow |

              @blue @green
              Examples:
               | colour |
               | white  |
        EOS
        feature.rewind
      end
    end

    it 'Single Feature Tag: colours' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :test_options => "-t @colours")
      expect(scenarios.length).to eq 7
    end

    it 'Single Scenario Tag: white' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :test_options => "-t @white")
      expect(scenarios.length).to eq 2
    end

    it 'Multiple Scenario Tags 1: black && white' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :test_options => "-t '@black and @white'")
      expect(scenarios.length).to eq 1
    end

    it 'Multiple Scenario Tags 2: black || white scenarios' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :test_options => "-t '@black or @white'")
      expect(scenarios.length).to eq 3
    end

    it 'Scenario Outline Tag: red' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :test_options => "-t @red")
      expect(scenarios.length).to eq 4
    end

    it 'Example Tag: blue' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :test_options => "-t @blue")
      expect(scenarios.length).to eq 3
    end

    it 'Multiple Example Tags 1: blue && green' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :test_options => "-t '@blue and @green'")
      expect(scenarios.length).to eq 1
    end

    it 'Multiple Example Tags 2: blue || green' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :test_options => "-t '@blue or @green'")
      expect(scenarios.length).to eq 4
    end

    it 'Single Negative Feature Tag: !colours' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :test_options => "-t 'not @colours'")
      expect(scenarios.length).to eq 0
    end

    it 'Single Negative Scenario Tag: !black' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :test_options => "-t 'not @black'")
      expect(scenarios.length).to eq 5
    end

    it 'Multiple Negative Scenario Tags And: !(black && white)' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :test_options => "-t 'not (@black and @white)'")
      expect(scenarios.length).to eq 6
    end

    it 'Multiple Negative Scenario Tags Or: !(black || red)' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :test_options => "-t 'not (@black or @red)'")
      expect(scenarios.length).to eq 1
    end

    it 'Negative Scenario Outline Tag: !red' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :test_options => "-t 'not @red'")
      expect(scenarios.length).to eq 3
    end

    it 'Negative Example Tag: !blue' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :test_options => "-t 'not @blue'")
      expect(scenarios.length).to eq 4
    end

    it 'Multiple Negative Example Tags 1: !blue && !green' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :test_options => "-t 'not @blue and not @green'")
      expect(scenarios.length).to eq 3
    end

    it 'Multiple Negative Example Tags 2: !blue || !green) ' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :test_options => "-t 'not @blue or not @green'")
      expect(scenarios.length).to eq 6
    end

    it 'Scenario and Example Mixed Tags: black || green' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :test_options => "-t '@black or @green'")
      expect(scenarios.length).to eq 4
    end

    it 'Positive and Negative Mixed Tags: red && !blue' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :test_options => "-t '@red and not @blue'")
      expect(scenarios.length).to eq 1
    end

    it 'Multiple Positive and Negative Mixed Tags: (white && black) || (red && !blue)' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :test_options => "--tags '(not @white and @black) or (@red and not @green)'")
      expect(scenarios.length).to eq 3
    end

    it 'Ignore Tag Pattern Feature: colours' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :ignore_tag_pattern => "@colours")
      expect(scenarios.length).to eq 0
    end

    it 'Ignore Tag Pattern Scenario: black' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :ignore_tag_pattern => "@black")
      expect(scenarios.length).to eq 5
    end

    it 'Ignore Tag Pattern Scenario Outline: red' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :ignore_tag_pattern => "@red")
      expect(scenarios.length).to eq 3
    end

    it 'Ignore Tag Pattern Example: green' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :ignore_tag_pattern => "@green")
      expect(scenarios.length).to eq 5
    end

    it 'Ignore Tag Pattern Multiple Tags: black || red' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :ignore_tag_pattern => "@black or @red")
      expect(scenarios.length).to eq 1
    end

    it 'Scenario Mixed tags: black && !blue with Ignore Tag Pattern Multiple Tags: red || white' do
      scenarios = ParallelTests::Cucumber::Scenarios.all([feature_file.path], :test_options => "-t '@black and not @blue'", :ignore_tag_pattern => "@red or @white")
      expect(scenarios.length).to eq 1
    end
  end
end