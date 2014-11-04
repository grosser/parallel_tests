require 'test/unit/testcase'

defined?(ROOT_DIR) or raise "ROOT_DIR must be defined first"

class Test::Unit::TestCase
  class << self
    def test_filename
      @test_filename
    end

    def inherited(base)
      if test_caller = caller.find { |caller| caller.start_with?(ROOT_DIR+'/test/') }
        relative_filename = test_caller[(ROOT_DIR.size+1)..-1].gsub(/:\d+:in .*\z/,'')
        base.instance_variable_set(:@test_filename, relative_filename)
      else
        STDERR.puts "Warning: can't find #{base} test/ filename anywhere in #{caller.inspect}"
      end
    end
  end
end
