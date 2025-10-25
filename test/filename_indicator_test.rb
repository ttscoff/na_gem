# frozen_string_literal: true

require_relative "test_helper"

class FilenameIndicatorTest < Minitest::Test
  SUBDIR = 'sub'

  def setup
    create_temp_files
    FileUtils.mkdir_p(SUBDIR)
    NA.create_todo(File.join(SUBDIR, 'sub.taskpaper'), 'Sub')
  end

  def teardown
    clean_up_temp_files
    FileUtils.rm_rf(SUBDIR)
  end

  def build_action(path)
    NA::Action.new(path, File.basename(path, ".#{NA.extension}"), ['Proj'], 'Do it', 1)
  end

  def test_cwd_indicator_hidden_when_only_root_files
    NA.show_cwd_indicator = false
    a = build_action('test.taskpaper')
    s = a.pretty(template: { templates: { output: '%filename%action' } }, detect_width: false)
    refute_match(%r{\./}, s, 'should not include ./ when flag is false and file in cwd')
  end

  def test_cwd_indicator_shown_when_subdir_present
    NA.show_cwd_indicator = true
    a = build_action('test.taskpaper')
    s = a.pretty(template: { templates: { output: '%filename%action' } }, detect_width: false)
    assert_match(%r{\./}, s, 'should include ./ when flag is true')
  end
end
