# frozen_string_literal: true

require_relative 'test_helper'
require 'json'

class TimeOutputTest < Minitest::Test
  def setup
    clean_up_temp_files
    create_temp_files
    @file = File.expand_path('test.taskpaper')
    # Seed timed actions
    now = Time.now
    NA.add_action(@file, 'Inbox', 'A @tag1 @tag2', [], started_at: now - 3600, done_at: now)
    NA.add_action(@file, 'Inbox', 'B @tag2', [], started_at: now - 1800, done_at: now)
    # Untimed action
    NA.add_action(@file, 'Inbox', 'C @tag3', [])
  end

  def teardown
    clean_up_temp_files
  end

  def with_stubbed_screen
    TTY::Screen.stub(:width, 80) do
      TTY::Screen.stub(:size, [80, 24]) do
        yield
      end
    end
  end

  def test_only_timed_filters_actions
    todo = NA::Todo.new(file_path: @file, require_na: false, done: true)
    actions = todo.actions
    NA::Pager.paginate = false
    out = nil
    with_stubbed_screen do
      out = capture_io do
        actions.output(1, files: [@file], only_timed: true, times: true)
      end.first
    end
    # Should not include untimed 'C'
    refute_match(/\bC\b/, out)
    # Count only per-action duration tokens (exclude totals/footer)
    per_action_tokens = out.scan(/(?<!Total time: )\[\d{2}:\d{2}:\d{2}:\d{2}\]/)
    assert_equal 2, per_action_tokens.size
  end

  def test_only_times_suppresses_action_lines
    todo = NA::Todo.new(file_path: @file, require_na: false, done: true)
    actions = todo.actions
    NA::Pager.paginate = false
    out = nil
    with_stubbed_screen do
      out = capture_io do
        actions.output(1, files: [@file], only_times: true, times: true, human: false)
      end.first
    end
    # Should not contain any action names
    refute_match(/\bA\b|\bB\b|\bC\b/, out)
    # Should contain a markdown table header
    assert_match(/\|\s*Tag\s*\|\s*Duration\s*\|/, out)
  end

  def test_json_times_structure
    todo = NA::Todo.new(file_path: @file, require_na: false, done: true)
    actions = todo.actions
    out = nil
    with_stubbed_screen do
      out = capture_io do
        actions.output(1, files: [@file], json_times: true, times: true)
      end.first
    end
    data = JSON.parse(out)
    assert_kind_of Array, data['timed']
    assert_kind_of Array, data['tags']
    assert_kind_of Hash, data['total']
    # Ensure durations are integers
    assert data['total']['seconds'].is_a?(Integer)
    # Ensure timed entries include required keys
    first = data['timed'].first
    %w[action started ended duration].each { |k| assert first.key?(k) }
  end
end
