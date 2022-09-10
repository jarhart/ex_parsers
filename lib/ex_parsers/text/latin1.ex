defmodule ExParsers.Text.Latin1 do
  @moduledoc """
  Text parsing primitives for text encoded as Latin1.
  """
  @spec __using__([]) :: Macro.t()
  defmacro __using__([]) do
    quote do
      use ExParsers.Text
      require unquote(__MODULE__)
      import unquote(__MODULE__)
    end
  end

  use ExParsers.Types
  alias ExParsers.Text.Character.{Any, Char, NoneOf, OneOf, Satisfy}
  alias ExParsers.Text.Charset.Latin1, as: Charset

  @spec any() :: Macro.t()
  @doc """
  Match any character.

  iex> "foo" |> match(any())
  {:success, "oo", 1, ?f}

  iex> "" |> match(any())
  {:failure, "", 0, {{:unexpected, :EOF}, 0}}
  """
  defmacro any(), do: Any.compile(quote(do: c), quote(do: c))

  @spec char(Macro.t()) :: Macro.t()
  @doc """
  Match an exact character.

  iex> "foo" |> match(char('f'))
  {:success, "oo", 1, ?f}

  iex> "boo" |> match(char('f'))
  {:failure, "boo", 0, {{:expected, "`f'"}, 0}}

  iex> c = ?f
  iex> "foo" |> match(char(c))
  {:success, "oo", 1, ?f}

  iex> c = ?f
  iex> "boo" |> match(char(c))
  {:failure, "boo", 0, {{:expected, "`f'"}, 0}}
  """
  defmacro char(c) when is_integer(c), do: Char.compile(c, quote(do: unquote(c)))

  defmacro char([c]) when is_integer(c), do: quote(do: char(unquote(c)))

  defmacro char(<<c>>), do: quote(do: char(unquote(c)))

  defmacro char(c), do: quote(do: satisfy(&(&1 == unquote(c)), "`#{[unquote(c)]}'"))

  @spec one_of(Macro.t()) :: Macro.t()
  @doc """
  Match any single character in `chars`. The argument can be a character list,
  a character range, an atom with a posix character class name, or a list of
  any of these.

  iex> "foo" |> match(one_of('abcdefg'))
  {:success, "oo", 1, ?f}

  iex> "foo" |> match(one_of(?a..?g))
  {:success, "oo", 1, ?f}

  iex> "foo" |> match(one_of([?A..?G, ?a..?g]))
  {:success, "oo", 1, ?f}

  iex> "foo" |> match(one_of('abc'))
  {:failure, "foo", 0, {{:expected, "one of 'abc'"}, 0}}

  iex> "foo" |> match(one_of(?a..?c))
  {:failure, "foo", 0, {{:expected, "one of ?a..?c"}, 0}}

  iex> "foo" |> match(one_of(:alpha))
  {:success, "oo", 1, ?f}

  iex> "foo" |> match(one_of(:digit))
  {:failure, "foo", 0, {{:expected, "digit"}, 0}}
  """
  defmacro one_of(chars), do: OneOf.compile(chars, quote(do: c), quote(do: c), Charset)

  @spec none_of(Macro.t()) :: Macro.t()
  @doc """
  Match any single character not in `chars`. The argument can be a character
  list, a character range, an atom with a posix character class name, or a list
  of any of these.

  iex> "foo" |> match(none_of('abcde'))
  {:success, "oo", 1, ?f}

  iex> "foo" |> match(none_of(?a..?e))
  {:success, "oo", 1, ?f}

  iex> "foo" |> match(none_of('abcdefg'))
  {:failure, "foo", 0, {{:expected, "none of 'abcdefg'"}, 0}}

  iex> "foo" |> match(none_of(?a..?g))
  {:failure, "foo", 0, {{:expected, "none of ?a..?g"}, 0}}
  """
  defmacro none_of(chars), do: NoneOf.compile(chars, quote(do: c), quote(do: c), Charset)

  @spec satisfy(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match any single character for which `predicate` returns `true`.

  iex> "foo" |> match(satisfy(&(&1 == ?f)))
  {:success, "oo", 1, ?f}

  iex> "foo" |> match(satisfy(&(&1 in 'bdg')))
  {:failure, "foo", 0, {{:expected, "one of 'bdg'"}, 0}}

  iex> "foo" |> match(satisfy(&(&1 == ?b)))
  {:failure, "foo", 0, {{:expected, "`b'"}, 0}}
  """
  defmacro satisfy(predicate, name \\ nil),
    do: Satisfy.compile(predicate, name, quote(do: c), quote(do: c), Charset)
end
