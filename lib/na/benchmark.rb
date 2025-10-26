# frozen_string_literal: true

module NA
  # Provides benchmarking utilities for measuring code execution time.
  #
  # @example Measure a block of code
  #   NA::Benchmark.measure('sleep') { sleep(1) }
  module Benchmark
    class << self
      attr_accessor :enabled, :timings

      # Initialize benchmarking state
      #
      # @return [void]
      def init
        @enabled = %w[1 true].include?(ENV.fetch('NA_BENCHMARK', nil))
        @timings = []
        @start_time = Time.now
      end

      # Measure the execution time of a block
      #
      # @param label [String] Label for the measurement
      # @return [Object] Result of the block
      # @example
      #   NA::Benchmark.measure('sleep') { sleep(1) }
      def measure(label)
        return yield unless @enabled

        start = Time.now
        result = yield
        duration = ((Time.now - start) * 1000).round(2)
        @timings << { label: label, duration: duration, timestamp: (start - @start_time) * 1000 }
        result
      end

      # Output a performance report to STDERR
      #
      # @return [void]
      # @example
      #   NA::Benchmark.report
      def report
        return unless @enabled

        total = @timings.sum { |t| t[:duration] }
        warn "\n#{NA::Color.template('{y}=== NA Performance Report ===')}"
        warn NA::Color.template("{dw}Total: {bw}#{total.round(2)}ms{x}")
        warn NA::Color.template("{dw}GC Count: {bw}#{GC.count}{x}") if defined?(GC)
        if defined?(GC)
          warn NA::Color.template("{dw}Memory: {bw}#{(GC.stat[:heap_live_slots] * 40 / 1024.0).round(1)}KB{x}")
        end
        warn ''

        @timings.each do |timing|
          pct = total.positive? ? ((timing[:duration] / total) * 100).round(1) : 0
          bar = '█' * [(pct / 2).round, 50].min
          warn NA::Color.template(
            "{dw}[{y}#{bar.ljust(25)}{dw}] {bw}#{timing[:duration].to_s.rjust(7)}ms {dw}(#{pct.to_s.rjust(5)}%) {x}#{timing[:label]}"
          )
        end
        warn NA::Color.template("{y}#{'=' * 50}{x}\n")
      end
    end
  end
end
