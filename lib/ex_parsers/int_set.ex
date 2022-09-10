defmodule ExParsers.IntSet do
  @moduledoc """
  `IntSet` implements a range set of integers. It serves as a building block
  for character sets.
  """

  @type t() :: [{integer(), integer()}]

  @spec new(integer() | {integer(), integer()} | Enumerable.t()) :: t()
  def new(member_or_members), do: insert([], member_or_members)

  @spec build(Enumerable.t(), (integer() -> boolean())) :: t()
  def build(range, fun), do: new(Stream.filter(range, fun))

  @spec insert(t(), integer() | Enumerable.t()) :: t()
  def insert(int_set, {min, max}), do: union(int_set, [{min, max}])
  def insert(int_set, min..max), do: union(int_set, [{min, max}])
  def insert(int_set, {:.., _, [min, max]}), do: union(int_set, [{min, max}])
  def insert(int_set, i) when is_integer(i), do: union(int_set, [{i, i}])
  def insert(int_set, members), do: Enum.reduce(members, int_set, &insert(&2, &1))

  @spec union(t(), t()) :: t()
  def union(s, []), do: s
  def union([], s), do: s

  def union(a, b) do
    [h | t] = :lists.merge(&(min(&1) <= min(&2)), a, b)

    Enum.reduce(t, [h], fn
      {_, max1}, [{_, max0} | _] = stack when max0 >= max1 -> stack
      {min1, max1}, [{min0, max0} | rest] when max0 + 1 >= min1 -> [{min0, max1} | rest]
      range, stack -> [range | stack]
    end)
    |> Enum.reverse()
  end

  @spec complement(t(), Range.t()) :: t()
  def complement(int_set, min..max) do
    int_set
    |> Enum.reduce({min, []}, fn {x, y}, {min, acc} ->
      {y + 1, (min < x && [{min, x - 1} | acc]) || acc}
    end)
    |> then(fn {min, acc} ->
      (min <= max && [{min, max} | acc]) || acc
    end)
    |> Enum.reverse()
  end

  @spec member?(t(), integer()) :: boolean()
  def member?(int_set, c), do: Enum.any?(int_set, fn {min, max} -> c in min..max end)

  @spec positive_guard(t() | {integer(), integer()}, Macro.t()) :: Macro.t()
  def positive_guard({i, i}, c), do: quote(do: unquote(c) == unquote(i))

  def positive_guard({min, max}, c), do: quote(do: unquote(c) in unquote(min)..unquote(max))

  def positive_guard([h | t], c) when length(t) < 3 do
    Enum.reduce(
      t,
      positive_guard(h, c),
      &quote(do: unquote(&2) or unquote(positive_guard(&1, c)))
    )
  end

  def positive_guard(int_set, c), do: split_guard(int_set, c, &positive_guard/2)

  @spec negative_guard(t() | {integer(), integer()}, Macro.t()) :: Macro.t()
  def negative_guard({i, i}, c), do: quote(do: unquote(c) != unquote(i))

  def negative_guard({min, max}, c), do: quote(do: unquote(c) not in unquote(min)..unquote(max))

  def negative_guard([h | t], c) when length(t) < 3 do
    Enum.reduce(
      t,
      negative_guard(h, c),
      &quote(do: unquote(&2) and unquote(negative_guard(&1, c)))
    )
  end

  def negative_guard(int_set, c), do: split_guard(int_set, c, &negative_guard/2)

  defp split_guard(int_set, c, fun) do
    {left, right} = Enum.split(int_set, div(length(int_set), 2))

    quote do
      (unquote(c) < unquote(min(right)) and unquote(fun.(left, c))) or unquote(fun.(right, c))
    end
  end

  defp min({min, _}), do: min
  defp min([{min, _} | _]), do: min
end
