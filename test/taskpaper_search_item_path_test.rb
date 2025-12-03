# frozen_string_literal: true

require_relative 'test_helper'
require 'na/next_action'

class TaskpaperSearchItemPathTest < Minitest::Test
  def setup
    @file = 'taskpaper_search_item_path_test.taskpaper'
    File.write(@file, <<~TP)
      Inbox:
      \tProject A:
      \t\t- Task in A @na
      \tProject B:
      \t\t- Task in B @na @done(2025-01-01)
    TP
  end

  def teardown
    FileUtils.rm_f(@file)
  end

  def test_parse_taskpaper_search_clauses_with_item_path
    clauses = NA.parse_taskpaper_search_clauses('@search(/Inbox//Project A and @na and not @done)')
    refute_empty clauses
    clause = clauses.first
    assert_includes clause[:item_paths], '/Inbox//Project A'
    assert(clause[:tags].any? { |t| t[:tag] =~ /na/ })
  end

  def test_run_taskpaper_search_filters_to_item_path_subtree
    # Extend fixture to include a Bugs subtree and an Archive project
    File.write(@file, <<~TP)
      Inbox:
      \tProject A:
      \t\t- Task in A @na
      \tBugs:
      \t\t- Bug 1 @na
      \t\t- Bug 2 @na @done(2025-01-01)
      Archive:
      \tOld:
      \t\t- Old task @na
    TP

    NA::Pager.paginate = false

    output = capture_io do
      NA.run_taskpaper_search(
        '@search(/Inbox//Bugs and @na and not @done)',
        file: @file,
        options: {
          depth: 1,
          notes: false,
          nest: false,
          omnifocus: false,
          no_file: false,
          times: false,
          human: false,
          search_notes: true,
          invert: false,
          regex: false,
          project: nil,
          done: false,
          require_na: false
        }
      )
    end.first

    # Should include only the Bugs subtree (as a project) and exclude others
    assert_match(/Inbox:Bugs/, output)
    refute_match(/Project A/, output)
    refute_match(/Archive/, output)
  end

  def test_project_shortcut_expands_to_project_equals
    clauses = NA.parse_taskpaper_search_clauses('@search(project Inbox)')
    refute_empty clauses
    clause = clauses.first
    assert_equal 'Inbox', clause[:project]
  end

  def test_slice_applied_to_entire_expression
    # Two @na, not-done actions and one done; slice [0] should return only the
    # first matching action.
    file = 'slice_test.taskpaper'
    File.write(file, <<~TP)
      Inbox:
      \t- First @na
      \t- Second @na
      \t- Third @na @done(2025-01-01)
    TP

    NA.debug = true
    NA.verbose = true

    actions, = NA.evaluate_taskpaper_search(
      '@search((project Inbox and @na and not @done)[0])',
      file: file,
      options: {
        depth: 1,
        notes: false,
        nest: false,
        omnifocus: false,
        no_file: false,
        times: false,
        human: false,
        search_notes: true,
        invert: false,
        regex: false,
        project: nil,
        done: false,
        require_na: false
      }
    )

    assert_equal 1, actions.size
    assert_includes actions.first.action, 'First'
    refute_includes actions.first.action, 'Second'
  ensure
    FileUtils.rm_f(file)
  end
end
