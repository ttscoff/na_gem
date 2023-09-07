# frozen_string_literal: true

class ::Array
  ##
  ## Like Array#compact -- removes nil items, but also
  ## removes empty strings, zero or negative numbers and FalseClass items
  ##
  ## @return     [Array] Array without "bad" elements
  ##
  def remove_bad
    compact.map { |x| x.is_a?(String) ? x.strip : x }.select(&:good?)
  end

  def wrap(width, indent, color)
    map! do |l|
      "#{color}#{' ' * indent }• #{l.wrap(width, indent)}{x}"
    end
    "\n#{join("\n")}"
  end
end
