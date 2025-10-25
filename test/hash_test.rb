require_relative "test_helper"
require "na/hash"

class HashExtTest < Minitest::Test
  def test_symbolize_keys_recursively
    h = { "a" => 1, "b" => { "c" => 2 } }
    result = h.symbolize_keys
    assert_equal({ a: 1, b: { c: 2 } }, result)
  end

  def test_deep_freeze_and_thaw
    h = { a: { b: [1, 2] }, c: "str" }
    frozen = h.deep_freeze
    assert frozen.frozen?
    assert frozen[:a].frozen?
    assert frozen[:c].frozen?
    thawed = frozen.deep_thaw
    refute thawed.frozen?
    refute thawed[:a].frozen?
    refute thawed[:c].frozen?
  end

  def test_deep_merge_combines_hashes_and_arrays
    h1 = { a: { b: [1, 2] }, c: 1 }
    h2 = { a: { b: [2, 3] }, c: 2, d: 3 }
    merged = h1.deep_merge(h2)
    assert_equal [1, 2, 3], merged[:a][:b]
    assert_equal 2, merged[:c]
    assert_equal 3, merged[:d]
  end
end
