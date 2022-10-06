# frozen_string_literal: true

class ::String
  def indent_level
    prefix = match(/(^[ \t]+)/)
    return 0 if prefix.nil?

    tabs = prefix[1].gsub(/  /, "\t").scan(/\t/).count

    tabs
  end

  ##
  ## Colorize @tags with ANSI escapes
  ##
  ## @param      color  [String] color (see #Color)
  ##
  ## @return     [String] string with @tags highlighted
  ##
  def highlight_tags(color: '{m}', value: '{y}', parens: '{m}', last_color: '{g}')
    tag_color = NA::Color.template(color)
    paren_color = NA::Color.template(parens)
    value_color = NA::Color.template(value)
    gsub(/(\s|m)(@[^ ("']+)(?:(\()(.*?)(\)))?/, "\\1#{tag_color}\\2#{paren_color}\\3#{value_color}\\4#{paren_color}\\5#{last_color}")
  end

  def matches(any: [], all: [], none: [])
    matches_any(any) && matches_all(all) && matches_none(none)
  end

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

  def wildcard_to_rx
    gsub(/\*/, '.*?').gsub(/\?/, '.')
  end

  def cap_first!
    replace cap_first
  end

  def cap_first
    sub(/^([a-z])(.*)$/) do
      m = Regexp.last_match
      m[1].upcase << m[2]
    end
  end
end
