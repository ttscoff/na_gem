# frozen_string_literal: true

require_relative 'test_helper'

class DepthTest < Minitest::Test
  SUBDIR = 'test_subdir'
  HIDDEN_SUBDIR = '.hidden_subdir'
  FILE = File.join(SUBDIR, 'test.taskpaper')
  HIDDEN_FILE = File.join(HIDDEN_SUBDIR, 'hidden.taskpaper')

  def setup
    create_temp_files
    FileUtils.mkdir_p(SUBDIR)
    NA.create_todo(FILE, 'DepthTest')
    FileUtils.mkdir_p(HIDDEN_SUBDIR)
    NA.create_todo(HIDDEN_FILE, 'HiddenDepthTest')
  end

  def teardown
    clean_up_temp_files
    FileUtils.rm_rf(SUBDIR)
    FileUtils.rm_rf(HIDDEN_SUBDIR)
  end

  def test_find_files_depth_1_does_not_include_subdir
    files = NA.find_files(depth: 1)
    assert files.include?('test.taskpaper'), 'root file should be present at depth 1'
    refute files.include?(FILE), 'subdir file should not be present at depth 1'
  end

  def test_find_files_depth_3_includes_subdir
    files = NA.find_files(depth: 3)
    assert files.include?(FILE), 'subdir file should be found when depth>=2'
  end

  def test_hidden_dirs_excluded_by_default
    files = NA.find_files(depth: 3)
    refute files.include?(HIDDEN_FILE), 'hidden subdir file should not be present by default'
  end

  def test_hidden_dirs_included_when_requested
    files = NA.find_files(depth: 3, include_hidden: true)
    assert files.include?(HIDDEN_FILE), 'hidden subdir file should be present when include_hidden is true'
  end
end
