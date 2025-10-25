#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple performance test script that doesn't require bundler
require_relative 'lib/na/benchmark'

# Mock the required dependencies
module NA
  module Color
    def self.template(input)
      input.to_s # Simple mock
    end
  end

  module Theme
    def self.load_theme
      {
        parent: '{c}',
        bracket: '{dc}',
        parent_divider: '{xw}/',
        action: '{bg}',
        project: '{xbk}',
        templates: {
          output: '%parent%action',
          default: '%parent%action'
        }
      }
    end
  end

  def self.theme
    @theme ||= Theme.load_theme
  end

  def self.notify(msg, debug: false)
    puts msg if debug
  end
end

# Initialize benchmark
NA::Benchmark.init

# Test the optimizations
puts 'Testing performance optimizations...'

# Test 1: Theme caching
NA::Benchmark.measure('Theme loading (first time)') do
  NA::Theme.load_theme
end

NA::Benchmark.measure('Theme loading (cached)') do
  NA.theme
end

# Test 2: Color template caching
NA::Benchmark.measure('Color template (first time)') do
  NA::Color.template('{bg}Test action{x}')
end

NA::Benchmark.measure('Color template (cached)') do
  NA::Color.template('{bg}Test action{x}')
end

# Test 3: Multiple operations
NA::Benchmark.measure('Multiple theme calls') do
  100.times do
    NA.theme
  end
end

NA::Benchmark.measure('Multiple color templates') do
  100.times do
    NA::Color.template("{bg}Action {c}#{rand(1000)}{x}")
  end
end

# Report results
NA::Benchmark.report
