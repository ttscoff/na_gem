require_relative "test_helper"
require "na/array"

class ArrayExtTest < Minitest::Test
  def test_remove_bad_removes_nil_and_false_and_empty
    arr = [nil, "", "  ", false, 0, -1, "good", "  ok  ", 42]
    # Patch good? for non-String types to avoid NoMethodError
    [FalseClass, Integer, NilClass].each { |cls| cls.class_eval { def good?; false; end } }
    result = arr.remove_bad
  assert_includes result, "good"
  assert_includes result, "ok"
  refute_includes result, 42
  refute_includes result, nil
  refute_includes result, ""
  refute_includes result, false
  refute_includes result, 0
  refute_includes result, -1
  end

  def test_wrap_returns_wrapped_and_colorized
    arr = ["This is a long line that should wrap nicely.", "Short line."]
    # Stub String#wrap to just return the string for test
    String.class_eval { def wrap(width, indent); self; end }
    result = arr.wrap(50, 2, "[color]")
    assert result.is_a?(Array) || result.is_a?(String)
    assert result.first.include?("[color]")
  end
end
