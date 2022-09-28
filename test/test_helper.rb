require "minitest/autorun"
require '../lib/na'
require 'fileutils'
# Add test libraries you want to use here, e.g. mocha
# Add helper classes or methods here, too

def create_temp_files
  NA.create_todo('test.taskpaper', 'test')
  NA.create_todo('test2.taskpaper', 'test2')
end

def clean_up_temp_files
  FileUtils.rm('test.taskpaper')
  FileUtils.rm('test2.taskpaper')
end
