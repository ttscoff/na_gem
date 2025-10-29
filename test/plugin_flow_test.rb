# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative 'test_helper'
require_relative '../lib/na'

class PluginFlowTest < Minitest::Test
  def with_temp_todo
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'todo.taskpaper')
      File.write(file, <<~TP)
        Inbox:
        	- Do a thing @na
      TP
      # Ensure NA defaults for tests
      NA.extension = 'taskpaper'
      NA.na_tag = 'na'
      yield file
    end
  end

  def test_update_action_in_place
    with_temp_todo do |file|
      todo = NA::Todo.new(file_path: file, require_na: false)
      action = todo.actions.find { |a| a.na? } || todo.actions.first
      refute_nil action
      # Build plugin return to add @foo tag
      io = {
        'file_path' => action.file_path,
        'line' => action.file_line,
        'parents' => [action.project] + action.parent,
        'text' => (action.action + ' @foo'),
        'note' => '',
        'tags' => [{ 'name' => 'foo', 'value' => '' }],
        'action' => { 'action' => 'UPDATE', 'arguments' => [] }
      }
      NA.apply_plugin_result(io)
      content = File.read(file)
      assert_match(/@foo/, content)
      # Ensure not duplicated action line
      assert_equal 1, content.lines.grep(/- Do a thing/).size
    end
  end

  def test_move_action_when_parents_change
    with_temp_todo do |file|
      todo = NA::Todo.new(file_path: file, require_na: false)
      action = todo.actions.find { |a| a.na? } || todo.actions.first
      new_parents = ['Inbox', 'Moved']
      io = {
        'file_path' => action.file_path,
        'line' => action.file_line,
        'parents' => new_parents,
        'text' => action.action,
        'note' => '',
        'tags' => [],
        'action' => { 'action' => 'MOVE', 'arguments' => ['Inbox:Moved'] }
      }
      NA.apply_plugin_result(io)
      content = File.read(file)
      assert_match(/^\tMoved:/, content)
    end
  end
end


