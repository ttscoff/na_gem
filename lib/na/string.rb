# frozen_string_literal: true

class ::String
  def indent_level
    prefix = match(/(^[ \t]+)/)
    return 0 if prefix.nil?

    prefix[1].gsub(/  /, "\t").scan(/\t/).count
  end

  ##
  ## Colorize @tags with ANSI escapes
  ##
  ## @param      color  [String] color (see #Color)
  ##
  ## @return     [String] string with @tags highlighted
  ##
  def highlight_tags(color: '{m}', value: '{y}', parens: '{m}')
    tag_color = NA::Color.template(color)
    paren_color = NA::Color.template(parens)
    value_color = NA::Color.template(value)
    gsub(/(\s|m)(@[^ ("']+)(?:(\()(.*?)(\)))?/, "\\1#{tag_color}\\2#{paren_color}\\3#{value_color}\\4#{paren_color}\\5")
  end
end
