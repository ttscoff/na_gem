require_relative "test_helper"
require "na/colors"

class ColorsTest < Minitest::Test
  def setup
    NA::Color.coloring = true
  end

  def teardown
    NA::Color.coloring = true
  end

  def test_white_method
    expected = "\e[37mtest\e[0m"
    result = NA::Color.white("test")
    assert_equal expected, result
  end

  def test_colors_hash_keys
    keys = NA::Color.colors_hash.keys
    %i[w k g l y c m r W K G L Y C M R d b u i x].each do |key|
      assert_includes keys, key
    end
  end

  def test_template_coloring
    expected = "\e[31mRed\e[0m \e[32mGreen\e[0m"
    str = NA::Color.template("{r}Red{x} {g}Green{x}")
    assert_equal expected, str
  end

  def test_coloring_toggle
    NA::Color.coloring = false
    result = NA::Color.white("test")
    assert_equal "test", result
    NA::Color.coloring = true
  end

  def test_normalize_color
  assert_equal 'boldred', 'bright_red'.dup.extend(NA::Color).normalize_color
  assert_equal 'boldbg', 'bgbold'.dup.extend(NA::Color).normalize_color
  assert_equal 'boldyellow', 'bright_yellow'.dup.extend(NA::Color).normalize_color
  end

  def test_last_color_code
  colored = "\e[31mRed\e[0m".dup
  assert_match(/\e\[0m/, colored.extend(NA::Color).last_color_code)
  end

  def test_uncolor
  colored = "\e[31mRed\e[0m".dup
  assert_equal 'Red', NA::Color.uncolor(colored)
  end

  def test_attributes
    attrs = NA::Color.attributes
    assert_includes attrs, :red
    assert_includes attrs, :bold
    assert_includes attrs, :bgwhite
  end

  def test_rgb_foreground
    assert_equal "\e[38;2;255;0;0m", NA::Color.rgb("#ff0000")
    assert_equal "\e[38;2;0;255;0m", NA::Color.rgb("#00ff00")
    assert_equal "\e[38;2;0;0;255m", NA::Color.rgb("#0000ff")
  end

  def test_rgb_background
    assert_equal "\e[48;2;255;0;0m", NA::Color.rgb("bg#ff0000")
    assert_equal "\e[48;2;0;255;0m", NA::Color.rgb("bg#00ff00")
    assert_equal "\e[48;2;0;0;255m", NA::Color.rgb("bg#0000ff")
  end

  def test_rgb_short_hex
    assert_equal "\e[38;2;255;255;255m", NA::Color.rgb("#fff")
    assert_equal "\e[48;2;255;255;255m", NA::Color.rgb("bg#fff")
    assert_equal "\e[38;2;17;34;51m", NA::Color.rgb("#123")
  end

  def test_validate_color
  assert_equal 'red', 'red'.dup.extend(NA::Color).validate_color
  assert_equal 'boldred', 'brightred'.dup.extend(NA::Color).validate_color
  assert_equal 'bgred', 'bgred'.dup.extend(NA::Color).validate_color
  assert_equal 'bg#ff0000', 'bg#ff0000'.dup.extend(NA::Color).validate_color
  assert_equal 'bold', 'bgbold'.dup.extend(NA::Color).validate_color
  assert_nil 'notacolor'.dup.extend(NA::Color).validate_color
  end
end
