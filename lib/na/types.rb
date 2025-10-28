# frozen_string_literal: true

require 'na/string'

module NA
  # Custom types for GLI
  # Provides natural language date/time and duration parsing
  # Uses chronify gem for parsing
  module Types
    module_function

    # Normalize shorthand relative durations to phrases Chronic can parse.
    # Examples:
    #  - "30m ago"    => "30 minutes ago"
    #  - "-30m"       => "30 minutes ago"
    #  - "2h30m"      => "2 hours 30 minutes ago" (when default_past)
    #  - "2h 30m ago" => "2 hours 30 minutes ago"
    #  - "2:30 ago"   => "2 hours 30 minutes ago"
    #  - "-2:30"      => "2 hours 30 minutes ago"
    # Accepts d,h,m units; hours:minutes pattern; optional leading '-'; optional 'ago'.
    # @param value [String] the duration string to normalize
    # @param default_past [Boolean] whether to default to past tense
    # @return [String] the normalized duration string
    def normalize_relative_duration(value, default_past: false)
      return value if value.nil?

      s = value.to_s.strip
      return s if s.empty?

      has_ago = s =~ /\bago\b/i
      negative = s.start_with?('-')

      text = s.sub(/^[-+]/, '')

      # hours:minutes pattern (e.g., 2:30, 02:30)
      if (m = text.match(/^(\d{1,2}):(\d{1,2})(?:\s*ago)?$/i))
        hours = m[1].to_i
        minutes = m[2].to_i
        parts = []
        parts << "#{hours} hours" if hours.positive?
        parts << "#{minutes} minutes" if minutes.positive?
        return "#{parts.join(' ')} ago"
      end

      # Compound d/h/m (order independent, allow spaces): e.g., 1d2h30m, 2h 30m, 30m
      days = hours = minutes = 0
      found = false
      if (dm = text.match(/(?:(\d+)\s*d)/i))
        days = dm[1].to_i
        found = true
      end
      if (hm = text.match(/(?:(\d+)\s*h)/i))
        hours = hm[1].to_i
        found = true
      end
      if (mm = text.match(/(?:(\d+)\s*m)/i))
        minutes = mm[1].to_i
        found = true
      end

      if found
        parts = []
        parts << "#{days} days" if days.positive?
        parts << "#{hours} hours" if hours.positive?
        parts << "#{minutes} minutes" if minutes.positive?
        # Determine if we should make it past-tense
        return "#{parts.join(' ')} ago" if negative || has_ago || default_past

        return parts.join(' ')

      end

      # Fall through: not a shorthand we handle
      s
    end

    # Parse a natural-language/iso date string for a start time
    # @param value [String] the date string to parse
    # @return [Time] the parsed date, or nil if parsing fails
    def parse_date_begin(value)
      return nil if value.nil? || value.to_s.strip.empty?

      # Prefer explicit ISO first (only if the value looks ISO-like)
      iso_rx = /\A\d{4}-\d{2}-\d{2}(?:[ T]\d{1,2}:\d{2}(?::\d{2})?)?\z/
      if value.to_s.strip =~ iso_rx
        begin
          return Time.parse(value)
        rescue StandardError
          # fall through to chronify
        end
      end

      # Fallback to chronify with guess begin
      begin
        # Normalize shorthand (e.g., 2h30m, -2:30, 30m ago)
        txt = normalize_relative_duration(value.to_s, default_past: true)
        # Bias to past for expressions like "ago", "yesterday", or "last ..."
        future = txt !~ /(\bago\b|yesterday|\blast\b)/i
        result = txt.chronify(guess: :begin, future: future)
        NA.notify("Parsed '#{value}' as #{result}", debug: true) if result
        result
      rescue StandardError
        nil
      end
    end

    # Parse a natural-language/iso date string for an end time
    # @param value [String] the date string to parse
    # @return [Time] the parsed date, or nil if parsing fails
    def parse_date_end(value)
      return nil if value.nil? || value.to_s.strip.empty?

      # Prefer explicit ISO first (only if the value looks ISO-like)
      iso_rx = /\A\d{4}-\d{2}-\d{2}(?:[ T]\d{1,2}:\d{2}(?::\d{2})?)?\z/
      if value.to_s.strip =~ iso_rx
        begin
          return Time.parse(value)
        rescue StandardError
          # fall through to chronify
        end
      end

      # Fallback to chronify with guess end
      value.to_s.chronify(guess: :end, future: false)
    end

    # Convert duration expressions to seconds
    # Supports: "90" (minutes), "45m", "2h", "1d2h30m", with optional leading '-' or trailing 'ago'
    # Also supports "2:30", "2:30 ago", and word forms like "2 hours 30 minutes (ago)"
    # @param value [String] the duration string to parse
    # @return [Integer] the duration in seconds, or nil if parsing fails
    def parse_duration_seconds(value)
      return nil if value.nil?

      s = value.to_s.strip
      return nil if s.empty?

      # Strip leading sign and optional 'ago'
      s = s.sub(/^[-+]/, '')
      s = s.sub(/\bago\b/i, '').strip

      # H:MM pattern
      m = s.match(/^(\d{1,2}):(\d{1,2})$/)
      if m
        hours = m[1].to_i
        minutes = m[2].to_i
        return (hours * 3600) + (minutes * 60)
      end

      # d/h/m compact with letters, order independent (e.g., 1d2h30m, 2h 30m, 30m)
      m = s.match(/^(?:(?<day>\d+)\s*d)?\s*(?:(?<hour>\d+)\s*h)?\s*(?:(?<min>\d+)\s*m)?$/i)
      if m && !m[0].strip.empty? && (m['day'] || m['hour'] || m['min'])
        return [[m['day'], 86_400], [m['hour'], 3600], [m['min'], 60]].map { |q, mult| q ? q.to_i * mult : 0 }.sum
      end

      # Word forms: e.g., "2 hours 30 minutes", "1 day 2 hours", etc.
      days = 0
      hours = 0
      minutes = 0
      found_word = false
      if (dm = s.match(/(\d+)\s*(?:day|days)\b/i))
        days = dm[1].to_i
        found_word = true
      end
      if (hm = s.match(/(\d+)\s*(?:hour|hours|hr|hrs)\b/i))
        hours = hm[1].to_i
        found_word = true
      end
      if (mm = s.match(/(\d+)\s*(?:minute|minutes|min|mins)\b/i))
        minutes = mm[1].to_i
        found_word = true
      end
      return (days * 86_400) + (hours * 3600) + (minutes * 60) if found_word

      # Plain number => minutes
      return s.to_i * 60 if s =~ /^\d+$/

      # Last resort: try chronify two points and take delta
      begin
        start = Time.now
        finish = s.chronify(context: 'now', guess: :end, future: false)
        return (finish - start).abs.to_i if finish
      rescue StandardError
        # ignore
      end

      nil
    end
  end
end
