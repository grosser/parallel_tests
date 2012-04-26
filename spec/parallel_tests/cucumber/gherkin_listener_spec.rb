require 'parallel_tests/cucumber/gherkin_listener'

describe ParallelTests::Cucumber::GherkinListener do
  describe :collect do
    before(:each) do
      @listener = ParallelTests::Cucumber::GherkinListener.new
      @listener.uri("feature_file")
    end

    it "returns steps count" do
      3.times {@listener.step(nil)}
      @listener.collect.should == {"feature_file" => 3}
    end

    it "counts background steps separately" do
      @listener.background("background")
      5.times {@listener.step(nil)}
      @listener.collect.should == {"feature_file" => 0}

      @listener.scenario("scenario")
      2.times {@listener.step(nil)}
      @listener.collect.should == {"feature_file" => 2}

      @listener.scenario("scenario")
      @listener.collect.should == {"feature_file" => 2}

      @listener.eof
      @listener.collect.should == {"feature_file" => 12}
    end

    it "counts scenario outlines steps separately" do
      @listener.scenario_outline("outline")
      5.times {@listener.step(nil)}
      @listener.collect.should == {"feature_file" => 0}

      @listener.scenario("scenario")
      2.times {@listener.step(nil)}
      @listener.collect.should == {"feature_file" => 2}

      @listener.scenario("scenario")
      @listener.collect.should == {"feature_file" => 2}

      3.times {@listener.examples}
      @listener.eof
      @listener.collect.should == {"feature_file" => 17}
    end
  end
end
