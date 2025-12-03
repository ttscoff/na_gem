require_relative "test_helper"
require "na/todo"

class TodoTest < Minitest::Test
  def test_initialize_with_empty_options
    todo = NA::Todo.new
    assert_instance_of NA::Todo, todo
    assert_kind_of Array, todo.actions
    assert_kind_of Array, todo.projects
    assert_kind_of Array, todo.files
  end

  def test_parse_returns_arrays
    todo = NA::Todo.new
    files, = todo.parse({})
    assert_kind_of Array, files
  end

  def test_parse_with_file_path
    File.write("test_todo_file.taskpaper", "Inbox:\n- Test Action @testing")
    todo = NA::Todo.new
    files, = todo.parse({ file_path: "test_todo_file.taskpaper" })
    assert_includes files, "test_todo_file.taskpaper"
    File.delete("test_todo_file.taskpaper")
  end

  def test_parse_with_search_and_tag
    File.write("test_todo_file.taskpaper", "Inbox:\n- Test Action @testing")
    todo = NA::Todo.new
    _, actions, = todo.parse({ file_path: "test_todo_file.taskpaper", search: "Test Action", tag: [{ tag: "testing" }], require_na: false })
    assert actions.any? { |a| a.to_s.include?("Test Action") }
    File.delete("test_todo_file.taskpaper")
  end

  def test_parse_with_negate
    File.write("test_todo_file.taskpaper", "Inbox:\n- Test Action @testing\n- Another Action")
    todo = NA::Todo.new
    _, actions, = todo.parse({ file_path: "test_todo_file.taskpaper", search: "Test Action", negate: true })
    refute actions.any? { |a| a.to_s.include?("Test Action") }
    File.delete("test_todo_file.taskpaper")
  end

  def test_outdented_actions_belong_to_parent_project
    File.write("indent_test.taskpaper", <<~TP)
      Inbox: @bucket @.todo
      \tNew Videos:
      \t\t- Style Stealer @na
      \t\t- Custom Rules @na
      \t- Update export video on website @na
    TP

    todo = NA::Todo.new
    _, actions, = todo.parse({ file_path: "indent_test.taskpaper", require_na: false })

    style = actions.find { |a| a.action.include?("Style Stealer") }
    update = actions.find { |a| a.action.include?("Update export video on website") }

    refute_nil style
    refute_nil update

    assert_equal ["Inbox", "New Videos"], style.parent
    assert_equal ["Inbox"], update.parent
  ensure
    FileUtils.rm_f("indent_test.taskpaper")
  end

  def test_top_level_actions_remain_under_inbox
    File.write("indent_root_test.taskpaper", <<~TP)
      Inbox:
      - Top level action @na
    TP

    todo = NA::Todo.new
    _, actions, = todo.parse({ file_path: "indent_root_test.taskpaper", require_na: false })

    action = actions.find { |a| a.action.include?("Top level action") }
    refute_nil action
    assert_equal ["Inbox"], action.parent
  ensure
    FileUtils.rm_f("indent_root_test.taskpaper")
  end
end