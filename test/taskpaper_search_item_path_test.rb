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
end
