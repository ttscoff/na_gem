require_relative "test_helper"
require "na/action"
require "tty-screen"

class ActionsTest < Minitest::Test
  def test_pretty_with_nil_file
    action = NA::Action.new(nil, "Project", ["Project"], "Test Action", 1)
    TTY::Screen.stub(:width, 80) do
      TTY::Screen.stub(:size, [80, 24]) do
        assert_silent do
          result = action.pretty
          assert result.is_a?(String)
        end
      end
    end
  end
end