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

  def test_format_multi_action_input
    require "na/action"
    actions = [
      NA::Action.new('./test1.taskpaper', "Project1", [], "Action 1", 10, ["Note 1"]),
      NA::Action.new('./test2.taskpaper', "Project2", [], "Action 2", 20)
    ]

    content = NA::Editor.format_multi_action_input(actions)

    # Check for header comments
    assert_match(/Edit the action text/, content)
    assert_match(/Blank lines/, content)

    # Check for file markers
    assert_match(/------ .*taskpaper:10/, content)
    assert_match(/------ .*taskpaper:20/, content)

    # Check for action content
    assert_match(/Action 1/, content)
    assert_match(/Action 2/, content)

    # Check for notes
    assert_match(/Note 1/, content)
  end

  def test_format_multi_action_input_with_notes
    require "na/action"
    actions = [
      NA::Action.new('./test.taskpaper', "Project", [], "Action", 15, ["Note line 1", "Note line 2"])
    ]

    content = NA::Editor.format_multi_action_input(actions)

    assert_match(/Action/, content)
    assert_match(/Note line 1/, content)
    assert_match(/Note line 2/, content)
  end

  def test_parse_multi_action_output
    content = <<~CONTENT
      # Do not edit # comment lines. Add notes on new lines after the action.
      # Blank lines will be ignored

      # ------ ./test1.taskpaper:10
      Updated Action 1
      Updated Note 1

      # ------ ./test2.taskpaper:20
      Updated Action 2
    CONTENT

    results = NA::Editor.parse_multi_action_output(content)

    assert_equal 2, results.length

    # Check first action
    assert results.has_key?('./test1.taskpaper:10')
    action1, note1 = results['./test1.taskpaper:10']
    assert_equal "Updated Action 1", action1
    assert_equal ["Updated Note 1"], note1

    # Check second action
    assert results.has_key?('./test2.taskpaper:20')
    action2, note2 = results['./test2.taskpaper:20']
    assert_equal "Updated Action 2", action2
    assert_empty note2
  end

  def test_parse_multi_action_output_ignores_comments_and_blanks
    content = <<~CONTENT
      # Some comment
      # Do not edit # comment lines

      # ------ ./test.taskpaper:5
      Action with notes
      Note 1
      Note 2

      # Another comment
    CONTENT

    results = NA::Editor.parse_multi_action_output(content)

    assert_equal 1, results.length
    assert results.has_key?('./test.taskpaper:5')
    action, note = results['./test.taskpaper:5']
    assert_equal "Action with notes", action
    assert_equal ["Note 1", "Note 2"], note
  end

  def test_parse_multi_action_output_single_action
    content = <<~CONTENT
      # ------ ./test.taskpaper:1
      Single action
    CONTENT

    results = NA::Editor.parse_multi_action_output(content)

    assert_equal 1, results.length
    action, note = results['./test.taskpaper:1']
    assert_equal "Single action", action
    assert_empty note
  end

  def test_parse_multi_action_output_with_multiple_notes
    content = <<~CONTENT
      # ------ ./test.taskpaper:1
      Main action
      First note
      Second note
      Third note
    CONTENT

    results = NA::Editor.parse_multi_action_output(content)
    action, note = results['./test.taskpaper:1']
    assert_equal "Main action", action
    assert_equal ["First note", "Second note", "Third note"], note
  end
end
