# frozen_string_literal: true

# String helpers
class ::String
  ##
  ## Determine indentation level of line
  ##
  ## @return     [Number] number of indents detected
  ##
  def indent_level
    prefix = match(/(^[ \t]+)/)
    return 0 if prefix.nil?

    prefix[1].gsub(/  /, "\t").scan(/\t/).count
  end

  ##
  ## Colorize @tags with ANSI escapes
  ##
  ## @param      color       [String] color (see #Color)
  ## @param      value       [String] The value color
  ##                         template
  ## @param      parens      [String] The parens color
  ##                         template
  ## @param      last_color  [String] Color to restore after
  ##                         tag highlight
  ##
  ## @return     [String] string with @tags highlighted
  ##
  def highlight_tags(color: '{m}', value: '{y}', parens: '{m}', last_color: '{xg}')
    tag_color = NA::Color.template(color)
    paren_color = NA::Color.template(parens)
    value_color = NA::Color.template(value)
    gsub(/(\s|m)(@[^ ("']+)(?:(\()(.*?)(\)))?/,
         "\\1#{tag_color}\\2#{paren_color}\\3#{value_color}\\4#{paren_color}\\5#{last_color}")
  end

  ##
  ## Highlight search results
  ##
  ## @param      regexes     [Array] The regexes for the
  ##                         search
  ## @param      color       [String] The highlight color
  ##                         template
  ## @param      last_color  [String] Color to restore after
  ##                         highlight
  ##
  def highlight_search(regexes, color: '{y}', last_color: '{xg}')
    string = dup
    color = NA::Color.template(color)
    regexes.each do |rx|
      next if rx.nil?

      rx = Regexp.new(rx.wildcard_to_rx, Regexp::IGNORECASE) if rx.is_a?(String)

      string.gsub!(rx) do
        m = Regexp.last_match
        last = m.pre_match.last_color
        "#{color}#{m[0]}#{NA::Color.template(last)}"
      end
    end
    string
  end

  # Returns the last escape sequence from a string.
  #
  # @note       Actually returns all escape codes, with the
  #             assumption that the result of inserting them
  #             will generate the same color as was set at
  #             the end of the string. Because you can send
  #             modifiers like dark and bold separate from
  #             color codes, only using the last code may
  #             not render the same style.
  #
  # @return     [String]  All escape codes in string
  #
  def last_color
    scan(/\e\[[\d;]+m/).join('').gsub(/\e\[0m/, '')
  end

  ##
  ## Convert a directory path to a regular expression
  ##
  ## @note       Splits at / or :, adds variable distance
  ##             between characters, joins segments with
  ##             slashes and requires that last segment
  ##             match last segment of target path
  ##
  ## @param      distance  The distance
  ##
  def dir_to_rx(distance: 2)
    "#{split(%r{[/:]}).map { |comp| comp.split('').join(".{0,#{distance}}").gsub(/\*/, '[^ ]*?') }.join('.*?/.*?')}[^/]*?$"
  end

  def dir_matches(any: [], all: [])
    matches_any(any.map(&:dir_to_rx)) && matches_all(all.map(&:dir_to_rx))
  end

  def matches(any: [], all: [], none: [])
    matches_any(any) && matches_all(all) && matches_none(none)
  end

  ##
  ## Convert wildcard characters to regular expressions
  ##
  ## @return     [String] Regex string
  ##
  def wildcard_to_rx
    gsub(/\./, '\\.').gsub(/\?/, '.').gsub(/\*/, '[^ ]*?')
  end

  def cap_first!
    replace cap_first
  end

  ##
  ## Capitalize first character, leaving other
  ## capitalization in place
  ##
  ## @return     [String] capitalized string
  ##
  def cap_first
    sub(/^([a-z])(.*)$/) do
      m = Regexp.last_match
      m[1].upcase << m[2]
    end
  end

  private

  def matches_none(regexes)
    regexes.each do |rx|
      return false if match(Regexp.new(rx, Regexp::IGNORECASE))
    end
    true
  end

  def matches_any(regexes)
    regexes.each do |rx|
      return true if match(Regexp.new(rx, Regexp::IGNORECASE))
    end
    false
  end

  def matches_all(regexes)
    regexes.each do |rx|
      return false unless match(Regexp.new(rx, Regexp::IGNORECASE))
    end
    true
  end
end
