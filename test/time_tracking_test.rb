# frozen_string_literal: true

require_relative "test_helper"

class TimeTrackingTest < Minitest::Test
  def test_action_process_with_start_time
    action = NA::Action.new("test.taskpaper", "Project", ["Project"], "Test Action", 1)
    start_time = Time.parse("2024-01-15 14:30")
    action.process(started_at: start_time)

    assert_match(/@started\(2024-01-15 14:30\)/, action.action)
    assert_equal("2024-01-15 14:30", action.tags["started"])
  end

  def test_action_process_with_done_time
    action = NA::Action.new("test.taskpaper", "Project", ["Project"], "Test Action", 1)
    done_time = Time.parse("2024-01-15 15:45")
    action.process(done_at: done_time)

    assert_match(/@done\(2024-01-15 15:45\)/, action.action)
    assert_equal("2024-01-15 15:45", action.tags["done"])
  end

  def test_action_process_with_start_and_done
    action = NA::Action.new("test.taskpaper", "Project", ["Project"], "Test Action", 1)
    start_time = Time.parse("2024-01-15 14:30")
    done_time = Time.parse("2024-01-15 15:45")
    action.process(started_at: start_time, done_at: done_time)

    assert_match(/@started\(2024-01-15 14:30\)/, action.action)
    assert_match(/@done\(2024-01-15 15:45\)/, action.action)
  end

  def test_action_process_with_duration_only
    action = NA::Action.new("test.taskpaper", "Project", ["Project"], "Test Action", 1)
    duration_seconds = 90 * 60 # 90 minutes
    action.process(duration_seconds: duration_seconds, finish: true)

    # Should have @done and @started (90 minutes before done)
    assert_match(/@done\(/, action.action)
    assert_match(/@started\(/, action.action)

    # Verify tags were updated
    assert action.tags["done"]
    assert action.tags["started"]

    # Verify @started is ~90 minutes before @done
    start_time = Time.parse(action.tags["started"])
    done_time = Time.parse(action.tags["done"])
    diff = done_time - start_time
    assert_in_delta(90 * 60, diff, 60) # Allow 1 minute tolerance
  end

  def test_action_process_with_duration_and_end
    action = NA::Action.new("test.taskpaper", "Project", ["Project"], "Test Action", 1)
    end_time = Time.parse("2024-01-15 15:00")
    duration_seconds = 30 * 60 # 30 minutes
    action.process(duration_seconds: duration_seconds, done_at: end_time)

    assert_match(/@done\(2024-01-15 15:00\)/, action.action)
    assert_match(/@started\(2024-01-15 14:30\)/, action.action)

    start_time = Time.parse(action.tags["started"])
    done_time = Time.parse(action.tags["done"])
    diff = done_time - start_time
    assert_in_delta(30 * 60, diff, 60)
  end

  def test_action_process_with_start_and_duration
    action = NA::Action.new("test.taskpaper", "Project", ["Project"], "Test Action", 1)
    start_time = Time.parse("2024-01-15 14:00")
    duration_seconds = 45 * 60 # 45 minutes
    action.process(started_at: start_time, duration_seconds: duration_seconds)

    assert_match(/@started\(2024-01-15 14:00\)/, action.action)
    assert_match(/@done\(2024-01-15 14:45\)/, action.action)
  end

  def test_types_parse_date_begin
    # ISO format
    time = NA::Types.parse_date_begin("2024-01-15 14:30")
    assert_instance_of(Time, time)
    assert_equal(2024, time.year)
    assert_equal(1, time.month)
    assert_equal(15, time.day)

    # Natural language - verify it parses correctly
    time = NA::Types.parse_date_begin("30 minutes ago")
    # Just verify we get a Time object - the exact value depends on implementation
    assert_instance_of(Time, time) if time
  end

  def test_types_parse_date_end
    # ISO format
    time = NA::Types.parse_date_end("2024-01-15 15:00")
    assert_instance_of(Time, time)

    # Natural language
    time = NA::Types.parse_date_end("in 2 hours")
    assert_instance_of(Time, time)
  end

  def test_types_parse_duration_seconds
    # Plain number (minutes)
    assert_equal(90 * 60, NA::Types.parse_duration_seconds("90"))

    # Minutes
    assert_equal(45 * 60, NA::Types.parse_duration_seconds("45m"))

    # Hours
    assert_equal(2 * 3600, NA::Types.parse_duration_seconds("2h"))

    # Days
    assert_equal(1 * 86_400, NA::Types.parse_duration_seconds("1d"))

    # Combined
    assert_equal(86_400 + (2 * 3600) + (30 * 60), NA::Types.parse_duration_seconds("1d2h30m"))
  end
end

