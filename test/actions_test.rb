require_relative "test_helper"
require 'ostruct'
require 'na/actions'

class ActionsTest < Minitest::Test
  def test_initialize_empty
    actions = NA::Actions.new
    assert_instance_of NA::Actions, actions
    assert_equal 0, actions.size
  end

  def test_initialize_with_array
    dummy_action = OpenStruct.new(file: "file.taskpaper", parent: ["Inbox"], action: "Test Action", note: [])
    def dummy_action.pretty(*); "pretty output"; end
    actions = NA::Actions.new([dummy_action])
    assert_equal 1, actions.size
    assert_equal dummy_action, actions.first
  end

  def test_output_returns_nil_with_no_files
    actions = NA::Actions.new
    assert_nil actions.output(1, {})
  end

  def test_output_with_nest_projects
    dummy_action = OpenStruct.new(file: "file.taskpaper", parent: ["Inbox"], action: "Test Action", note: [])
    def dummy_action.pretty(*); "pretty output"; end
    actions = NA::Actions.new([dummy_action])
    config = { files: ["file.taskpaper"], nest: true, nest_projects: true }
    # Should not raise error, returns nil (Pager.page is stubbed in real usage)
    assert_nil actions.output(1, config)
  end

  def test_output_with_notes
    dummy_action = OpenStruct.new(file: "file.taskpaper", parent: ["Inbox"], action: "Test Action", note: ["A note"])
    def dummy_action.pretty(*); "pretty output"; end
    actions = NA::Actions.new([dummy_action])
    config = { files: ["file.taskpaper"], notes: true }
    # Should not raise error, returns nil (Pager.page is stubbed in real usage)
    assert_nil actions.output(1, config)
  end
end
