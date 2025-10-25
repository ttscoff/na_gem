# frozen_string_literal: true

REGEX_DAY = /^(mon|tue|wed|thur?|fri|sat|sun)(\w+(day)?)?$/i.freeze
REGEX_CLOCK = '(?:\d{1,2}+(?::\d{1,2}+)?(?: *(?:am|pm))?|midnight|noon)'
REGEX_TIME = /^#{REGEX_CLOCK}$/i.freeze

# String helpers
class ::String
  # Insert a comment character at the start of every line
  # @param char [String] The character to insert (default #)
  def comment(_char = '#')
    split("\n").map { |l| "# #{l}" }.join("\n")
  end

  # Tests if object is nil or empty
  # @return [Boolean] true if object is defined and has content
  def good?
    !strip.empty?
  end

  # Test if line should be ignored
  # @return [Boolean] line is empty or comment
  def ignore?
    line = self
    line =~ /^#/ || line.strip.empty?
  end

  def read_file
    file = File.expand_path(self)
    raise "Missing file #{file}" unless File.exist?(file)

    if File.directory?(file)
      if File.exist?("#{file}.#{NA.extension}")
        file = "#{file}.#{NA.extension}"
      elsif File.exist?("#{file}/#{File.basename(file)}.#{NA.extension}")
        file = "#{file}/#{File.basename(file)}.#{NA.extension}"
      else
        NA.notify("#{NA.theme[:error]}#{file} is a directory", exit_code: 2)
      end
    end

    # IO.read(file).force_encoding('ASCII-8BIT').encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
    File.read(file).force_encoding('utf-8')
  end

  # Determine indentation level of line
  # @return [Number] number of indents detected
  def indent_level
    prefix = match(/(^[ \t]+)/)
    return 0 if prefix.nil?

    prefix[1].gsub('    ', "\t").scan("\t").count
  end

  def action?
    self =~ /^[ \t]*- /
  end

  def blank?
    strip =~ /^$/
  end

  def project?
    !action? && self =~ /:( +@\S+(\([^)]*\))?)*$/
  end

  def project
    m = match(/^([ \t]*)([^\-][^@:]*?): *(@\S+ *)*$/)
    m ? m[2] : nil
  end

  def action
    sub(/^[ \t]*- /, '')
  end

  def done?
    self =~ /@done/
  end

  def na?
    self =~ /@#{NA.na_tag}\b/
  end

  # Colorize the dirname and filename of a path
  # @return [String] Colorized string
  def highlight_filename
    dir = File.dirname(self).shorten_path.trunc_middle(TTY::Screen.columns / 3)
    file = NA.include_ext ? File.basename(self) : File.basename(self, ".#{NA.extension}")
    "#{NA.theme[:dirname]}#{dir}/#{NA.theme[:filename]}#{file}{x}"
  end

  # Colorize @tags with ANSI escapes
  # @param color [String] color (see #Color)
  # @param value [String] The value color template
  # @param parens [String] The parens color template
  # @param last_color [String] Color to restore after tag highlight
  # @return [String] string with @tags highlighted
  def highlight_tags(color: NA.theme[:tags], value: NA.theme[:value], parens: NA.theme[:value_parens],
                     last_color: NA.theme[:action])
    tag_color = NA::Color.template(color)
    paren_color = NA::Color.template(parens)
    value_color = NA::Color.template(value)
    gsub(/(?<pre>\s|m)(?<tag>@[^ ("']+)(?:(?<lparen>\()(?<val>.*?)(?<rparen>\)))?/) do
      m = Regexp.last_match
      if m['val']
        "#{m['pre']}#{tag_color}#{m['tag']}#{paren_color}(#{value_color}#{m['val']}#{paren_color})#{last_color}"
      else
        "#{m['pre']}#{tag_color}#{m['tag']}#{last_color}"
      end
    end
  end

  # Highlight search results
  # @param regexes [Array] The regexes for the search
  # @param color [String] The highlight color template
  # @param last_color [String] Color to restore after highlight
  def highlight_search(regexes, color: NA.theme[:search_highlight], last_color: NA.theme[:action])
    string = dup
    color = NA::Color.template(color.dup)
    regexes.each do |rx|
      next if rx.nil?

      rx = Regexp.new(rx, Regexp::IGNORECASE) if rx.is_a?(String)

      string.gsub!(rx) do
        m = Regexp.last_match
        last = m.pre_match.last_color
        "#{color}#{m[0]}#{NA::Color.template(last)}"
      end
    end
    string
  end

  # Truncate the string in the middle, replacing the removed section with '[...]'.
  # @param max [Integer] Maximum allowed length of the string
  # @return [String] Truncated string with middle replaced if necessary
  def trunc_middle(max)
    return self unless length > max

    half = (max / 2).floor - 3
    chars = chars
    pre = chars.slice(0, half)
    post = chars.reverse.slice(0, half).reverse
    "#{pre.join}[...]#{post.join}"
  end

  # Wrap the string to a given width, indenting each line and preserving tag formatting.
  # @param width [Integer] The maximum line width
  # @param indent [Integer] Number of spaces to indent each line
  # @return [String] Wrapped string
  def wrap(width, indent)
    return "\n#{self}" if width <= 80

    output = []
    line = []
    length = 0
    gsub!(/(@\S+)\((.*?)\)/) { "#{Regexp.last_match(1)}(#{Regexp.last_match(2).gsub(/ /, '†')})" }

    split(' ').each do |word|
      uncolored = NA::Color.uncolor(word)
      if (length + uncolored.length + 1) <= width
        line << word
        length += uncolored.length + 1
      else
        output << line.join(' ')
        line = [word]
        length = uncolored.length + 1
      end
    end
    output << line.join(' ')
    # Indent all lines after the first
    output.each_with_index.map { |l, i| i.zero? ? l : (' ' * indent) + l }.join("\n").gsub(/†/, ' ')
  end

  # Returns the last escape sequence from a string.
  # @note Actually returns all escape codes, with the assumption that the result of inserting them will generate the same color as was set at end of the string. Because you can send modifiers like dark and bold separate from color codes, only using the last code may not render the same style.
  # @return [String] All escape codes in string
  def last_color
    scan(/\e\[[\d;]+m/).join.gsub("\e[0m", '')
  end

  # Convert a directory path to a regular expression
  # @note Splits at / or :, adds variable distance between characters, joins segments with slashes and requires that last segment match last segment of target path
  # @param distance [Integer] The distance allowed between characters
  # @param require_last [Boolean] Require match to be last element in path
  def dir_to_rx(distance: 1, require_last: true)
    "#{split(%r{[/:]}).map do |comp|
      comp.chars.join(".{0,#{distance}}").gsub('*', '[^ ]*?')
    end.join('.*?/.*?')}#{require_last ? '[^/]*?$' : ''}"
  end

  # Check if the string matches directory patterns using any, all, and none criteria.
  # @param any [Array] Patterns where any match is sufficient
  # @param all [Array] Patterns where all must match
  # @param none [Array] Patterns where none must match
  # @param require_last [Boolean] Require last segment match
  # @param distance [Integer] Allowed character distance in regex
  # @return [Boolean] True if matches criteria
  def dir_matches(any: [], all: [], none: [], require_last: true, distance: 1)
    any_rx = any.map { |q| q.dir_to_rx(distance: distance, require_last: require_last) }
    all_rx = all.map { |q| q.dir_to_rx(distance: distance, require_last: require_last) }
    none_rx = none.map { |q| q.dir_to_rx(distance: distance, require_last: false) }
    matches_any(any_rx) && matches_all(all_rx) && matches_none(none_rx)
  end

  # Check if the string matches any, all, and none regex patterns.
  # @param any [Array] Patterns where any match is sufficient
  # @param all [Array] Patterns where all must match
  # @param none [Array] Patterns where none must match
  # @return [Boolean] True if matches criteria
  def matches(any: [], all: [], none: [])
    matches_any(any) && matches_all(all) && matches_none(none)
  end

  # Convert wildcard characters to regular expressions
  # @return [String] Regex string
  def wildcard_to_rx
    gsub('.', '\\.').gsub('?', '.').gsub('*', '[^ ]*?')
  end

  # Capitalize the first character of the string in place.
  # @return [String] The modified string
  def cap_first!
    replace cap_first
  end

  # Capitalize first character, leaving other capitalization in place
  # @return [String] capitalized string
  def cap_first
    sub(/^([a-z])(.*)$/) do
      m = Regexp.last_match
      m[1].upcase << m[2]
    end
  end

  # Replace home directory with tilde
  # @return [String] shortened path
  def shorten_path
    sub(/^#{Dir.home}/, '~')
  end

  # Convert (chronify) natural language dates within configured date tags (tags whose value is expected to be a date). Modifies string in place.
  # @param additional_tags [Array] An array of additional tags to consider date_tags
  def expand_date_tags(additional_tags = nil)
    iso_rx = /\d{4}-\d\d-\d\d \d\d:\d\d/

    watch_tags = [
      'due',
      'start(?:ed)?',
      'beg[ia]n',
      'done',
      'finished',
      'completed?',
      'waiting',
      'defer(?:red)?'
    ]

    if additional_tags
      date_tags = additional_tags
      date_tags = date_tags.split(/ *, */) if date_tags.is_a?(String)
      date_tags.map! do |tag|
        tag.sub(/^@/, '').gsub(/\((?!\?:)(.*?)\)/, '(?:\1)').strip
      end
      watch_tags.concat(date_tags).uniq!
    end

    done_rx = /(?<=^| )@(?<tag>#{watch_tags.join('|')})\((?<date>.*?)\)/i

    dup.gsub(done_rx) do
      m = Regexp.last_match
      t = m['tag']
      d = m['date']
      future = t =~ /^(done|complete)/ ? false : true
      parsed_date = d =~ iso_rx ? Time.parse(d) : d.chronify(guess: :begin, future: future)
      parsed_date.nil? ? m[0] : "@#{t}(#{parsed_date.strftime('%F %R')})"
    end
  end

  # Converts input string into a Time object when input takes on the following formats:
  #   - interval format e.g. '1d2h30m', '45m' etc.
  #   - a semantic phrase e.g. 'yesterday 5:30pm'
  #   - a strftime e.g. '2016-03-15 15:32:04 PDT'
  # @param options [Hash] Additional options
  # @option options :future [Boolean] assume future date (default: false)
  # @option options :guess [Symbol] :begin or :end to assume beginning or end of arbitrary time range
  # @return [DateTime] result
  def chronify(**options)
    now = Time.now
    raise StandardError, "Invalid time expression #{inspect}" if to_s.strip == ''

    secs_ago = if match(/^(\d+)$/)
                 # plain number, assume minutes
                 Regexp.last_match(1).to_i * 60
               elsif (m = match(/^(?:(?<day>\d+)d)? *(?:(?<hour>\d+)h)? *(?:(?<min>\d+)m)?$/i))
                 # day/hour/minute format e.g. 1d2h30m
                 [[m['day'], 24 * 3600],
                  [m['hour'], 3600],
                  [m['min'], 60]].map { |qty, secs| qty ? (qty.to_i * secs) : 0 }.reduce(0, :+)
               end

    if secs_ago
      res = now - secs_ago
      notify(%(date/time string "#{self}" interpreted as #{res} (#{secs_ago} seconds ago)), debug: true)
    else
      date_string = dup
      date_string = 'today' if date_string.match(REGEX_DAY) && now.strftime('%a') =~ /^#{Regexp.last_match(1)}/i
      date_string = "#{options[:context]} #{date_string}" if date_string =~ REGEX_TIME && options[:context]

      require 'chronic' unless defined?(Chronic)
      res = Chronic.parse(date_string, {
                            guess: options.fetch(:guess, :begin),
                            context: options.fetch(:future, false) ? :future : :past,
                            ambiguous_time_range: 8
                          })

      NA.notify(%(date/time string "#{self}" interpreted as #{res}), debug: true)
    end

    res
  end

  # Private helper methods for pattern matching
  private

  # Returns true if none of the regexes match the string.
  # @param regexes [Array] Array of regex patterns
  # @return [Boolean] True if none match
  def matches_none(regexes)
    regexes.each do |rx|
      return false if match(Regexp.new(rx, Regexp::IGNORECASE))
    end
    true
  end

  # Returns true if any of the regexes match the string.
  # @param regexes [Array] Array of regex patterns
  # @return [Boolean] True if any match
  def matches_any(regexes)
    regexes.each do |rx|
      return true if match(Regexp.new(rx, Regexp::IGNORECASE))
    end
    false
  end

  # Returns true if all of the regexes match the string.
  # @param regexes [Array] Array of regex patterns
  # @return [Boolean] True if all match
  def matches_all(regexes)
    regexes.each do |rx|
      return false unless match(Regexp.new(rx, Regexp::IGNORECASE))
    end
    true
  end
end
