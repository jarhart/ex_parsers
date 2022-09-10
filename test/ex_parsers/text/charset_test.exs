defmodule ExParsers.Text.CharsetTest do
  use ExUnit.Case

  doctest ExParsers.Text.Charset

  alias ExParsers.Text.Charset

  describe "new/2" do
    test "expands named charsets" do
      assert Charset.new([1..5, :foo], %{foo: [{8,10}]}) == [{1,5}, {8,10}]
    end

    test "merges overlapping named charsets" do
      assert Charset.new([1..5, :foo], %{foo: [{4,9}]}) == [{1,9}]
    end
  end

  describe "show_quoted/1" do

    test "shows a lists of chars as a charlist" do
      assert Charset.show_quoted(quote(do: 'αβγ')) == "'αβγ'"
    end

    test "shows escape chars escaped" do
      assert Charset.show_quoted(quote(do: ' \t\n\r')) == "' \\t\\n\\r'"
    end

    test "inspects atoms" do
      assert Charset.show_quoted(quote(do: [:digit, :punct])) == "[:digit, :punct]"
    end

    test "shows ranges using chars" do
      assert Charset.show_quoted(quote(do: [?A..?Z, ?a..?z])) == "[?A..?Z, ?a..?z]"
    end

    test "shows tuple ranges as ranges" do
      assert Charset.show_quoted(quote(do: [{?A, ?Z}, {?a, ?z}])) == "[?A..?Z, ?a..?z]"
    end
  end
end
