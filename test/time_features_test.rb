# frozen_string_literal: true

require_relative 'test_helper'

class TimeFeaturesTest < Minitest::Test
  def setup
    clean_up_temp_files
    create_temp_files
    @file = File.expand_path('test.taskpaper')
  end

  def teardown
    clean_up_temp_files
  end

  # Types.parse_date_begin shorthands and phrases
  def test_parse_date_begin_shorthands_and_phrases
    t1 = NA::Types.parse_date_begin('-2h30m')
    t2 = NA::Types.parse_date_begin('2:30 ago')
    t3 = NA::Types.parse_date_begin('2h30m')
    t4 = NA::Types.parse_date_begin('30m ago')

    [t1, t2, t3, t4].each do |t|
      next if t.nil?
      assert_instance_of Time, t
      # within last 1 day
      assert_operator(Time.now - t, :>=, 0)
      assert_operator(Time.now - t, :<=, 86_400)
    end
  end

  # Types.parse_duration_seconds extended forms
  def test_parse_duration_seconds_extended
    assert_equal 9_000, NA::Types.parse_duration_seconds('-2h30m')
    assert_equal 7_500, NA::Types.parse_duration_seconds('2:05 ago')
    assert_equal 9_000, NA::Types.parse_duration_seconds('2 hours 30 minutes ago')
    assert_equal 1_800, NA::Types.parse_duration_seconds('30m')
    assert_equal 86_400 + 3_600, NA::Types.parse_duration_seconds('1d1h')
  end

  # String#expand_date_tags on @started/@done natural language
  def test_expand_date_tags_normalizes_started_and_done
    s = 'Task @started(2 hours ago) @done(now)'
    out = s.expand_date_tags
    assert_match(/@started\(\d{4}-\d{2}-\d{2} \d{2}:\d{2}\)/, out)
    assert_match(/@done\(\d{4}-\d{2}-\d{2} \d{2}:\d{2}\)/, out)
  end

  # NA.add_action injects @started and @done
  def test_add_action_injects_started_and_done
    started_at = Time.now - 3_600
    done_at = Time.now
    NA.add_action(@file, 'Inbox', 'Injected times', [], started_at: started_at, done_at: done_at)

    content = File.read(@file)
    assert_match(/- Injected times .*@started\(\d{4}-\d{2}-\d{2} \d{2}:\d{2}\)/, content)
    assert_match(/@done\(\d{4}-\d{2}-\d{2} \d{2}:\d{2}\)/, content)
  end

  # update_action respects started_at/done_at when adding an existing Action
  def test_update_action_respects_started_and_done
    # Seed a simple action first
    NA.add_action(@file, 'Inbox', 'Seed', [])

    # Parse the file to find the action object we just added
    todo = NA::Todo.new(file_path: @file, require_na: false)
    action = todo.actions.find { |a| a.action =~ /Seed/ }
    refute_nil action

    started_at = Time.now - 1_800
    done_at = Time.now
    NA.update_action(@file, nil,
                     add: action,
                     project: 'Inbox',
                     started_at: started_at,
                     done_at: done_at)

    content = File.read(@file)
    assert_match(/- Seed .*@started\(\d{4}-\d{2}-\d{2} \d{2}:\d{2}\)/, content)
    assert_match(/@done\(\d{4}-\d{2}-\d{2} \d{2}:\d{2}\)/, content)
  end

  # Using duration to backfill started from end
  def test_add_action_duration_backfills_started
    done_at = Time.now
    NA.add_action(@file, 'Inbox', 'Backfill', [], done_at: done_at,
                  duration_seconds: 2 * 3600 + 30 * 60)
    content = File.read(@file)
    assert_match(/- Backfill .*@started\(\d{4}-\d{2}-\d{2} \d{2}:\d{2}\).*@done\(/, content)
  end
end
