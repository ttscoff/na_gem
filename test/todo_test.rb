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
end