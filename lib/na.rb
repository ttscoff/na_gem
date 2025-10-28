# frozen_string_literal: true

require 'na/benchmark' if ENV['NA_BENCHMARK']
# Define a dummy Benchmark if not available for tests
unless defined?(NA::Benchmark)
  module NA
    module Benchmark
      def self.measure(_label)
        yield
      end
    end
  end
end
require 'na/version'
require 'na/pager'
require 'time'
require 'fileutils'
require 'shellwords'
# Lazy load heavy gems - only load when needed
# require 'chronic'  # Loaded in action.rb and string.rb when needed
require 'tty-screen'
require 'tty-reader'
require 'tty-which'
require 'na/hash'
require 'na/colors'
require 'na/string'
require 'na/array'
require 'yaml'
require 'na/theme'
require 'na/todo'
require 'na/actions'
require 'na/project'
require 'na/action'
require 'na/types'
require 'na/editor'
require 'na/next_action'
require 'na/prompt'
require 'na/plugins'
