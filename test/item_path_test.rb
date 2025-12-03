# frozen_string_literal: true

require_relative 'test_helper'
require 'na/next_action'
require 'ostruct'

class ItemPathTest < Minitest::Test
  def test_parse_item_path_simple_child
    steps = NA.parse_item_path('/Inbox/New Videos')
    assert_equal 2, steps.length
    assert_equal :child, steps[0][:axis]
    assert_equal 'Inbox', steps[0][:text]
    assert_equal :child, steps[1][:axis]
    assert_equal 'New Videos', steps[1][:text]
  end

  def test_resolve_item_path_child
    projects = [
      NA::Project.new('Inbox', 0, 0, 10),
      NA::Project.new('Inbox:New Videos', 1, 1, 3),
      NA::Project.new('Inbox:Bugs', 1, 4, 6),
      NA::Project.new('Archive', 0, 11, 15)
    ]

    steps = NA.parse_item_path('/Inbox/New Videos')
    result_projects = NA.resolve_path_in_projects(projects, steps)
    paths = result_projects.map(&:project)
    assert_includes paths, 'Inbox:New Videos'
  end

  def test_resolve_item_path_descendant
    projects = [
      NA::Project.new('Inbox', 0, 0, 10),
      NA::Project.new('Inbox:New Videos', 1, 1, 3),
      NA::Project.new('Inbox:Bugs', 1, 4, 6),
      NA::Project.new('Archive', 0, 11, 15)
    ]

    steps = NA.parse_item_path('/Inbox//Bugs')
    result_projects = NA.resolve_path_in_projects(projects, steps)

    paths = result_projects.map(&:project)
    assert_includes paths, 'Inbox:Bugs'
  end

  def test_resolve_item_path_wildcard_root
    projects = [
      NA::Project.new('Inbox', 0, 0, 10),
      NA::Project.new('Inbox:New Videos', 1, 1, 3),
      NA::Project.new('Archive', 0, 11, 15)
    ]

    steps = NA.parse_item_path('/*')
    result_projects = NA.resolve_path_in_projects(projects, steps)
    paths = result_projects.map(&:project)
    assert_includes paths, 'Inbox'
    assert_includes paths, 'Archive'
  end
end
