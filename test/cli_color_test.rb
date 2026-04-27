# frozen_string_literal: true

require_relative 'test_helper'
require 'open3'

class CliColorTest < Minitest::Test
  ANSI_REGEX = /\e\[(?:(?:(?:[349]|10)[0-9]|[0-9])?;?)+m/.freeze

  def with_temp_home
    Dir.mktmpdir('na_home') do |home|
      Dir.mktmpdir('na_todo') do |dir|
        yield home, dir
      end
    end
  end

  def write_todo(dir)
    path = File.join(dir, 'test.taskpaper')
    File.write(path, <<~TASKPAPER)
      Inbox:
      	- Test color output @na
    TASKPAPER
    path
  end

  def run_na(*args, home:)
    env = {
      'HOME' => home,
      'XDG_CONFIG_HOME' => File.join(home, '.config')
    }
    Open3.capture3(env, RbConfig.ruby, '-Ilib', 'bin/na', *args, stdin_data: '')
  end

  def test_explicit_color_forces_color_when_stdout_is_not_tty
    with_temp_home do |home, dir|
      todo = write_todo(dir)

      stdout, stderr, status = run_na('--color', 'next', '--file', todo, '--no-file', home: home)

      assert status.success?, stderr
      assert_match ANSI_REGEX, stdout
    end
  end

  def test_explicit_color_after_global_file_forces_color_when_stdout_is_not_tty
    with_temp_home do |home, dir|
      todo = write_todo(dir)

      stdout, stderr, status = run_na('-f', todo, '--color', home: home)

      assert status.success?, stderr
      assert_match ANSI_REGEX, stdout
    end
  end

  def test_default_color_remains_plain_when_stdout_is_not_tty
    with_temp_home do |home, dir|
      todo = write_todo(dir)

      stdout, stderr, status = run_na('next', '--file', todo, '--no-file', home: home)

      assert status.success?, stderr
      refute_match ANSI_REGEX, stdout
    end
  end
end
