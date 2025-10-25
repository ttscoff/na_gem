# frozen_string_literal: true

class ::Array
  # Like Array#compact -- removes nil items, but also
  # removes empty strings, zero or negative numbers and FalseClass items
  #
  # @return [Array] Array without "bad" elements
  def remove_bad
    compact.map { |x| x.is_a?(String) ? x.strip : x }.select(&:good?)
  end

  # Wrap each string in the array to the given width and indent, with color
  #
  # @param width [Integer] Maximum line width
  # @param indent [Integer] Indentation spaces
  # @param color [String] Color code to apply
  # @return [Array, String] Wrapped and colorized lines
  def wrap(width, indent, color)
    return map { |l| "#{color}  #{l.wrap(width, 2)}" } if width < 60

    map! do |l|
      "#{color}#{' ' * indent}• #{l.wrap(width, indent)}{x}"
    end
    "\n#{join("\n")}"
  end
end
