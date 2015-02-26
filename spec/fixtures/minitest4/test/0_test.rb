require 'bundler/setup'
require 'minitest/autorun'
require 'parallel_tests/test/runtime_logger'

class Foo0 < MiniTest::Unit::TestCase
  def test_foo
    sleep 0.5
    assert true
  end
end

class Bar0 < MiniTest::Unit::TestCase
  def test_foo
    sleep 0.25
    assert true
  end
end
