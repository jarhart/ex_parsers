defmodule ExParsers.Text.Charset do
  @moduledoc """
  `Charset` represents a character set as an interval set of codepoints within
  a range.
  """
  alias ExParsers.IntSet

  @spec __using__(Macro.t()) :: Macro.t()
  defmacro __using__(range: range) do
    quote do
      @behaviour unquote(__MODULE__)

      @type t() :: unquote(IntSet).t()

      @range unquote(range)

      @spec range() :: Range.t()
      def range(), do: @range

      @spec new(integer() | Enumerable.t()) :: t()
      def new(chars), do: unquote(__MODULE__).new(chars, named_charsets())

      @spec build((integer() -> boolean())) :: t()
      def build(fun), do: unquote(IntSet).build(unquote(range), fun)

      @spec positive_guard(t(), Macro.t()) :: Macro.t()
      defdelegate positive_guard(charset, c), to: unquote(IntSet)

      @spec negative_guard(t(), Macro.t()) :: Macro.t()
      defdelegate negative_guard(charset, c), to: unquote(IntSet)

      @spec show_quoted(Macro.t()) :: String.t()
      defdelegate show_quoted(chars), to: unquote(__MODULE__)

      @spec union(t(), t()) :: t()
      defdelegate union(a, b), to: unquote(IntSet)

      @spec insert(t(), integer() | Range.t()) :: t()
      defdelegate insert(charset, c), to: unquote(IntSet)

      @spec complement(t()) :: t()
      def complement(charset), do: unquote(IntSet).complement(charset, unquote(range))
    end
  end

  @type t() :: IntSet.t()

  @callback named_charsets() :: %{atom() => t()}

  @spec new(integer() | Enumerable.t(), %{atom() => t()}) :: t()
  @doc """
  Creates a character set from the characters, ranges, or atoms in `chars`,
  replacing atoms with the values from `named_charsets`.
  """
  def new(chars, named_charsets \\ %{})

  def new(member, named_charsets)
      when is_integer(member) or is_tuple(member) or is_struct(member, Range) or is_atom(member),
      do: new(List.wrap(member), named_charsets)

  def new(chars, named_charsets) do
    {names, members} = List.flatten(chars) |> Enum.split_with(&is_atom/1)

    names
    |> Enum.map(&named_charsets[&1])
    |> Enum.reduce(IntSet.new(members), &IntSet.union/2)
  end

  @spec show_quoted(integer() | Enumerable.t()) :: String.t()
  def show_quoted(entries), do: show(dequote(entries))

  defp show(c) when is_integer(c), do: "?#{show_char(c)}"
  defp show(name) when is_atom(name), do: inspect(name)
  defp show({c, c}), do: show(c)
  defp show({min, max}), do: "#{show(min)}..#{show(max)}"

  defp show(entries) when is_list(entries) do
    if Enum.all?(entries, &is_integer/1) do
      "'#{Enum.map_join(entries, &show_char/1)}'"
    else
      "[" <> Enum.map_join(entries, ", ", &show/1) <> "]"
    end
  end

  defp show_char(?\b), do: "\\b"
  defp show_char(?\f), do: "\\f"
  defp show_char(?\n), do: "\\n"
  defp show_char(?\r), do: "\\r"
  defp show_char(?\t), do: "\\t"
  defp show_char(c) when is_integer(c), do: "#{[c]}"
  defp show_char(name) when is_atom(name), do: inspect(name)
  defp show_char({c, c}), do: show_char(c)
  defp show_char({min, max}), do: "?#{show_char(min)}..?#{show_char(max)}"

  def dequote({:.., _, [i, i]}), do: i
  def dequote(i..i), do: i
  def dequote({i, i}), do: i
  def dequote({:.., _, [min, max]}), do: {min, max}
  def dequote(min..max), do: {min, max}
  def dequote(l) when is_list(l), do: List.flatten(Enum.map(l, &dequote/1))
  def dequote(x), do: x
end
