require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
  add_group 'Library', 'lib/na'
end

require "minitest/autorun"
$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'na'
require 'fileutils'
# Add test libraries you want to use here, e.g. mocha
# Add helper classes or methods here, too

def create_temp_files
  NA.extension = 'taskpaper'
  NA.create_todo('test.taskpaper', 'test')
  NA.create_todo('test2.taskpaper', 'test2')
end

def clean_up_temp_files
  FileUtils.rm('test.taskpaper') if File.exist?('test.taskpaper')
  FileUtils.rm('test2.taskpaper') if File.exist?('test2.taskpaper')
  # Also clean up any remaining files from previous tests
  Dir.glob('*.taskpaper').each { |f| FileUtils.rm(f) if File.exist?(f) }
end
