require_relative "test_helper"
require "na/string"

class StringExtTest < Minitest::Test
  def test_wrap_splits_long_lines_and_indents
    s = "This is a very long line that should wrap at a certain width and indent. " * 5
    wrapped = s.wrap(60, 2)
    
    # Should contain line breaks and indentation
    # Only lines after the first are indented
    assert wrapped.lines[1..].any? { |line| line =~ /^  / }, 'should have indented lines after wrapping (after first line)'
    assert wrapped.lines.count > 1, 'should wrap to multiple lines'
    # Should preserve all words
    s.split.each { |word| assert_match(/#{word}/, wrapped) }
  end
  def test_comment_prepends_hash
    s = "line1\nline2"
    commented = s.comment
    assert_match(/^# line1/, commented)
    assert_match(/^# line2/, commented)
  end

  def test_good_returns_true_for_nonempty
    assert "ok".good?
    refute "   ".good?
    refute "".good?
  end

  def test_ignore_returns_true_for_comments_and_blank
    assert "# comment".ignore?
    assert "   ".ignore?
    refute "not ignored".ignore?
  end

  def test_indent_level_detects_tabs_and_spaces
    assert_equal 0, "noindent".indent_level
    assert_equal 1, "\tindented".indent_level
    assert_equal 2, "    \tmore".indent_level
  end

  def test_action_and_blank
    assert "  - do something".action?
    assert "   ".blank?
    refute "not blank".blank?
  end

  def test_highlight_filename_with_nil
    assert_equal '', nil.highlight_filename
  end
end
