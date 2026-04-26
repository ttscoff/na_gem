require_relative "test_helper"
require "na/next_action"

class NextAvailableActionsTest < Minitest::Test
  def with_temp_todo(content)
    Tempfile.create("na_next_available") do |tmp|
      tmp.write(content)
      tmp.flush
      yield tmp.path
    end
  end

  def test_first_available_per_project_with_na_tag
    NA.na_tag = "na"
    content = <<~TP
      Inbox:
      ProjectA:
      \t- First A @na
      \t- Second A @na
      ProjectB:
      \t- Only B @na
    TP

    with_temp_todo(content) do |path|
      todo = NA::Todo.new(file_path: path, require_na: true)
      actions = todo.actions

      assert actions.size >= 3, "expected at least three actions"

      selected = actions.first_available_per_project(require_na: true)
      parents = selected.map { |a| Array(a.parent).join(":") }

      assert_equal %w[ProjectA ProjectB].sort, parents.sort
      project_a = selected.find { |a| Array(a.parent).join(":") == "ProjectA" }
      refute_nil project_a
      assert_includes project_a.action, "First A"
    end
  end

  def test_first_available_per_project_without_na_tag
    NA.na_tag = "na"
    content = <<~TP
      Inbox:
      ProjectA:
      \t- First A no tag
      \t- Second A @na
      ProjectB:
      \t- First B no tag
      \t- Second B no tag @done(2025-01-01 10:00)
    TP

    with_temp_todo(content) do |path|
      todo = NA::Todo.new(file_path: path, require_na: false, done: false)
      actions = todo.actions

      selected = actions.first_available_per_project(require_na: false)
      parents = selected.map { |a| Array(a.parent).join(":") }

      assert_equal %w[ProjectA ProjectB].sort, parents.sort

      project_a = selected.find { |a| Array(a.parent).join(":") == "ProjectA" }
      project_b = selected.find { |a| Array(a.parent).join(":") == "ProjectB" }
      refute_nil project_a
      refute_nil project_b
      assert_includes project_a.action, "First A no tag"
      assert_includes project_b.action, "First B no tag"
    end
  end
end

