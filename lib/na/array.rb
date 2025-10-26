# frozen_string_literal: true

##
# Extensions to Ruby's Array class for todo management and formatting.
#
# @example Remove bad elements from an array
#   ['foo', '', nil, 0, false, 'bar'].remove_bad #=> ['foo', 'bar']
class ::Array
  # Like Array#compact -- removes nil items, but also
  # removes empty strings, zero or negative numbers and FalseClass items
  #
  # @return [Array] Array without "bad" elements
  # @example
  #   ['foo', '', nil, 0, false, 'bar'].remove_bad #=> ['foo', 'bar']
  def remove_bad
    compact.map { |x| x.is_a?(String) ? x.strip : x }.select(&:good?)
  end

  # Wrap each string in the array to the given width and indent, with color
  #
  # @param width [Integer] Maximum line width
  # @param indent [Integer] Indentation spaces
  # @param color [String] Color code to apply
  # @return [Array, String] Wrapped and colorized lines
  # @example
  #   ['foo', 'bar'].wrap(80, 2, '{g}') #=> "\n{g}  • foo{x}\n{g}  • bar{x}"
  def wrap(width, indent, color)
    return map { |l| "#{color}  #{l.wrap(width, 2)}" } if width < 60

    map! do |l|
      "#{color}#{' ' * indent}• #{l.wrap(width, indent)}{x}"
    end
    "\n#{join("\n")}"
  end
end
