require_relative "test_helper"
require "na/action"
require "tty-screen"

class ActionTest < Minitest::Test
  def test_pretty_with_nil_file
    action = NA::Action.new(nil, "Project", ["Project"], "Test Action", 1)
    TTY::Screen.stub(:width, 80) do
      TTY::Screen.stub(:size, [80, 24]) do
        assert_silent do
          result = action.pretty
          assert result.is_a?(String)
        end
      end
    end
  end

  def test_file_stores_path_line_format
    action = NA::Action.new('/path/to/file.taskpaper', "Project", ["Project"], "Test Action", 42)
    assert_equal "/path/to/file.taskpaper:42", action.file
    assert_equal 42, action.line
  end

  def test_file_parts_extraction
    action = NA::Action.new('/path/to/file.taskpaper', "Project", ["Project"], "Test Action", 42)
    file_path, line = action.file_line_parts
    assert_equal "/path/to/file.taskpaper", file_path
    assert_equal 42, line
  end

  def test_file_path_method
    action = NA::Action.new('/path/to/file.taskpaper', "Project", ["Project"], "Test Action", 42)
    assert_equal "/path/to/file.taskpaper", action.file_path
  end

  def test_file_line_method
    action = NA::Action.new('/path/to/file.taskpaper', "Project", ["Project"], "Test Action", 42)
    assert_equal 42, action.file_line
  end

  def test_file_line_parts_without_line_number
    # Test backward compatibility with nil line
    action = NA::Action.new('/path/to/file.taskpaper', "Project", ["Project"], "Test Action", nil)
    file_path, line = action.file_line_parts
    assert_equal "/path/to/file.taskpaper", file_path
    assert_nil line
  end

  def test_file_stores_path_only_when_no_line
    action = NA::Action.new('/path/to/file.taskpaper', "Project", ["Project"], "Test Action", nil)
    assert_equal "/path/to/file.taskpaper", action.file
    assert_nil action.line
  end

  def test_to_s_includes_path_line
    action = NA::Action.new('/path/to/file.taskpaper', "Project", ["Project"], "Test Action", 42, ["Note 1"])
    output = action.to_s
    assert_match(/\(.*file\.taskpaper:42\)/, output)
    assert_match(/Test Action/, output)
    assert_match(/Note 1/, output)
  end

  def test_to_s_pretty_includes_line_number
    action = NA::Action.new('/path/to/file.taskpaper', "Project", ["Project"], "Test Action", 42)
    output = action.to_s_pretty
    assert_match(/42/, output)
  end
end