require 'parallel_tests/gherkin/gherkin_listener'

describe ParallelTests::Gherkin::GherkinListener do
  describe :collect do
    before(:each) do
      @listener = ParallelTests::Gherkin::GherkinListener.new
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

    it 'counts scenarios that should not be ignored' do
      @listener.ignore_tag_pattern = nil
      @listener.scenario( stub('scenario', :tags =>[ stub('tag', :name => '@WIP' )]) )
      @listener.step(nil)
      @listener.eof
      @listener.collect.should == {"feature_file" => 1}

      @listener.ignore_tag_pattern = /@something_other_than_WIP/
      @listener.scenario( stub('scenario', :tags =>[ stub('tag', :name => '@WIP' )]) )
      @listener.step(nil)
      @listener.eof
      @listener.collect.should == {"feature_file" => 2}
    end

    it 'does not count scenarios that should be ignored' do
      @listener.ignore_tag_pattern = /@WIP/
      @listener.scenario( stub('scenario', :tags =>[ stub('tag', :name => '@WIP' )]))
      @listener.step(nil)
      @listener.eof
      @listener.collect.should == {"feature_file" => 0}
    end

    it 'counts outlines that should not be ignored' do
      @listener.ignore_tag_pattern = nil
      @listener.scenario_outline( stub('scenario', :tags =>[ stub('tag', :name => '@WIP' )]) )
      @listener.step(nil)
      3.times {@listener.examples}
      @listener.eof
      @listener.collect.should == {"feature_file" => 3}


      @listener.ignore_tag_pattern = /@something_other_than_WIP/
      @listener.scenario_outline( stub('scenario', :tags =>[ stub('tag', :name => '@WIP' )]) )
      @listener.step(nil)
      3.times {@listener.examples}
      @listener.eof
      @listener.collect.should == {"feature_file" => 6}
    end

    it 'does not count outlines that should be ignored' do
      @listener.ignore_tag_pattern = /@WIP/
      @listener.scenario_outline( stub('scenario', :tags =>[ stub('tag', :name => '@WIP' )]) )
      @listener.step(nil)
      3.times {@listener.examples}
      @listener.eof
      @listener.collect.should == {"feature_file" => 0}
    end

  end
end
