defmodule ExParsers.ErrorTest do
  use ExUnit.Case
  use ExUnitProperties
  doctest ExParsers.Error

  alias ExParsers.Error

  describe "alt" do
    test "returns the first error if it occurred later in the source" do
      error1 = {{:expected, "foo"}, 3}
      error2 = {{:expected, "bar"}, 2}

      assert Error.alt(error1, error2) == error1
    end

    test "returns the second error if it occurred later in the source" do
      error1 = {{:expected, "foo"}, 2}
      error2 = {{:expected, "bar"}, 3}

      assert Error.alt(error1, error2) == error2
    end

    test "merges :expected if the errors occurred at the same position" do
      error1 = {{:expected, "foo"}, 2}
      error2 = {{:expected, "bar"}, 2}

      assert Error.alt(error1, error2) == {{:expected, "foo or bar"}, 2}
    end

    test "returns the second error if they occurred at the same position and can't be merged" do
      error1 = {"bad!", 2}
      error2 = {"very bad!", 2}

      assert Error.alt(error1, error2) == error2
    end
  end

  describe "full_position/2" do
    property "finds the line and column within the given source at the given position" do
      check all lines <- list_of(string(:alphanumeric, min_length: 1), min_length: 1),
                line <- integer(0..(length(lines) - 1)),
                col <- integer(0..(String.length(Enum.at(lines, line)) - 1)),
                source = Enum.join(lines, "\n"),
                pos = Enum.reduce(Enum.take(lines, line), 0, &String.length(&1) + &2 + 1) + col do
        assert Error.full_position(source, pos) == {line, col}
      end
    end
  end
end
