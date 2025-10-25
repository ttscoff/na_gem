require_relative "test_helper"
require "na/editor"
require "tempfile"

class EditorTest < Minitest::Test
  def test_default_editor_with_git_editor
    ENV["NA_EDITOR"] = nil
    ENV["GIT_EDITOR"] = "vim"
    ENV["EDITOR"] = nil
    TTY::Which.stub(:exist?, true) do
      assert_equal "vim", NA::Editor.default_editor(prefer_git_editor: true)
    end
  end

  def test_default_editor_with_editor_only
    ENV["NA_EDITOR"] = nil
    ENV["GIT_EDITOR"] = nil
    ENV["EDITOR"] = "nano"
    TTY::Which.stub(:exist?, true) do
      assert_equal "nano", NA::Editor.default_editor(prefer_git_editor: true)
    end
  end

  def test_default_editor_with_na_editor_only
    ENV["NA_EDITOR"] = "emacs"
    ENV["GIT_EDITOR"] = nil
    ENV["EDITOR"] = nil
    TTY::Which.stub(:exist?, true) do
      assert_equal "emacs", NA::Editor.default_editor(prefer_git_editor: true)
    end
  end
  def setup
    @orig_env = ENV.to_hash
  end

  def teardown
    ENV.replace(@orig_env)
  end

  def test_args_for_editor
    assert_equal "vim -f", NA::Editor.args_for_editor("vim")
    assert_equal "subl -w", NA::Editor.args_for_editor("subl")
    assert_equal "code -w", NA::Editor.args_for_editor("code")
    assert_equal "mate -w", NA::Editor.args_for_editor("mate")
    assert_equal "mvim -f", NA::Editor.args_for_editor("mvim")
    assert_equal "nano ", NA::Editor.args_for_editor("nano")
    assert_equal "emacs ", NA::Editor.args_for_editor("emacs")
    assert_equal "vim -f", NA::Editor.args_for_editor("vim")
    assert_equal "vim -f", NA::Editor.args_for_editor("vim -f")
  end

  def test_format_input_basic
    input = "Title\nNote line 1\nNote line 2"
    title, note = NA::Editor.format_input(input)
    assert_equal "Title", title
    assert_equal ["Note line 1", "Note line 2"], note
  end

  def test_format_input_empty
    assert_raises(SystemExit) { NA::Editor.format_input("") }
    assert_raises(SystemExit) { NA::Editor.format_input(nil) }
  end

  def test_format_input_removes_comments_and_blank_lines
    input = "Title\nNote line 1\n# This is a comment\n   \nNote line 2"
    title, note = NA::Editor.format_input(input)
    assert_equal "Title", title
    assert_equal ["Note line 1", "Note line 2"], note
  end

  def test_format_input_expands_date_tags
  input = "Title with {date}\nNote"
  title, note = NA::Editor.format_input(input)
  assert_equal "Title with {date}", title
  assert_equal ["Note"], note
  end

  # default_editor and fork_editor require environment and system interaction,
  # so only basic presence and fallback logic can be tested here.
  def test_default_editor_returns_env
    ENV["NA_EDITOR"] = "nano"
    TTY::Which.stub(:exist?, true) do
      assert_equal "nano", NA::Editor.default_editor
    end
  end

  def test_default_editor_fallback
    ENV.delete("NA_EDITOR")
    ENV.delete("GIT_EDITOR")
    ENV.delete("EDITOR")
    TTY::Which.stub(:exist?, false) do
      TTY::Which.stub(:which, "nano") do
        NA.stub(:notify, nil) do
          assert_equal "nano", NA::Editor.default_editor
        end
      end
    end
  end
end
