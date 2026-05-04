# frozen_string_literal: true

require_relative 'test_helper'
require 'open3'

class UpdatePathLineTest < Minitest::Test
  def with_temp_home
    Dir.mktmpdir('na_home') do |home|
      Dir.mktmpdir('na_todo') do |dir|
        yield home, dir
      end
    end
  end

  def run_na(*args, home:)
    env = {
      'HOME' => home,
      'XDG_CONFIG_HOME' => File.join(home, '.config')
    }
    Open3.capture3(env, RbConfig.ruby, '-Ilib', 'bin/na', *args, stdin_data: '')
  end

  def test_update_path_line_uses_one_based_line_without_search_terms
    with_temp_home do |home, dir|
      todo = File.join(dir, 'test.taskpaper')
      File.write(todo, <<~TASKPAPER)
        Inbox:
        	- First Action
        	- Second Action
      TASKPAPER

      _stdout, stderr, status = run_na('update', '--tag', 'selected', "#{todo}:3", home: home)

      assert status.success?, stderr
      content = File.read(todo)
      assert_includes content, '- Second Action @selected'
      refute_includes content, '- First Action @selected'
    end
  end
end
