# frozen_string_literal: true

module NA
  module Benchmark
    class << self
      attr_accessor :enabled, :timings

      def init
        @enabled = ENV['NA_BENCHMARK'] == '1' || ENV['NA_BENCHMARK'] == 'true'
        @timings = []
        @start_time = Time.now
      end

      def measure(label)
        return yield unless @enabled

        start = Time.now
        result = yield
        duration = ((Time.now - start) * 1000).round(2)
        @timings << { label: label, duration: duration, timestamp: (start - @start_time) * 1000 }
        result
      end

      def report
        return unless @enabled

        total = @timings.sum { |t| t[:duration] }
        $stderr.puts "\n#{NA::Color.template('{y}=== NA Performance Report ===')}"
        $stderr.puts NA::Color.template("{dw}Total: {bw}#{total.round(2)}ms{x}")
        $stderr.puts NA::Color.template("{dw}GC Count: {bw}#{GC.count}{x}") if defined?(GC)
        $stderr.puts NA::Color.template("{dw}Memory: {bw}#{(GC.stat[:heap_live_slots] * 40 / 1024.0).round(1)}KB{x}") if defined?(GC)
        $stderr.puts ""

        @timings.each do |timing|
          pct = total > 0 ? ((timing[:duration] / total) * 100).round(1) : 0
          bar = '█' * [(pct / 2).round, 50].min
          $stderr.puts NA::Color.template(
            "{dw}[{y}#{bar.ljust(25)}{dw}] {bw}#{timing[:duration].to_s.rjust(7)}ms {dw}(#{pct.to_s.rjust(5)}%) {x}#{timing[:label]}"
          )
        end
        $stderr.puts NA::Color.template("{y}#{'=' * 50}{x}\n")
      end
    end
  end
end
