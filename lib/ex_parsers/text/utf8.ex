defmodule ExParsers.Text.Utf8 do
  @moduledoc """
  Text parsing primitives for text encoded as UTF-8.
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
  alias ExParsers.Text.Charset.Unicode, as: Charset

  @spec any() :: Macro.t()
  @doc """
  Match any UTF-8 character.

  iex> "über" |> match(any())
  {:success, "ber", 1, ?ü}
  """
  defmacro any(), do: Any.compile(quote(do: c), quote(do: c :: utf8))

  @spec char(Macro.t()) :: Macro.t()
  @doc """
  Match an exact UTF-8 character.

  iex> "über" |> match(char(?ü))
  {:success, "ber", 1, ?ü}

  iex> "foo" |> match(char(?ü))
  {:failure, "foo", 0, {{:expected, "`ü'"}, 0}}
  """
  defmacro char(c) when is_integer(c), do: Char.compile(c, quote(do: unquote(c) :: utf8))

  defmacro char([c]) when is_integer(c), do: quote(do: char(unquote(c)))

  defmacro char(<<c::utf8>>), do: quote(do: char(unquote(c)))

  defmacro char(c), do: quote(do: satisfy(&(&1 == unquote(c)), "`#{[unquote(c)]}'"))

  @spec one_of(charset()) :: Macro.t()
  @doc """
  Match any single UTF-8 character in `chars`. The argument can be a character
  list, a character range, an atom with a character class name, or a list of
  any of these.

  iex> "über" |> match(one_of('αβü'))
  {:success, "ber", 1, ?ü}

  iex> "über" |> match(one_of(:lowercase_letter))
  {:success, "ber", 1, ?ü}

  iex> "über" |> match(one_of('αβγ'))
  {:failure, "über", 0, {{:expected, "one of 'αβγ'"}, 0}}

  iex> "über" |> match(one_of(:uppercase_letter))
  {:failure, "über", 0, {{:expected, "uppercase_letter"}, 0}}
  """
  defmacro one_of(chars), do: OneOf.compile(chars, quote(do: c), quote(do: c :: utf8), Charset)

  @spec none_of(charset()) :: Macro.t()
  @doc """
  Match any single UTF-8 character not in `chars`. The argument can be a
  character list, a character range, an atom with a character class name, or a
  list of any of these.

  iex> "über" |> match(none_of('αβγ'))
  {:success, "ber", 1, ?ü}
  """
  defmacro none_of(chars), do: NoneOf.compile(chars, quote(do: c), quote(do: c :: utf8), Charset)

  @spec satisfy(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match any single UTF-8 character for which `predicate` returns `true`.

  iex> "über" |> match(satisfy(&(&1 == ?ü)))
  {:success, "ber", 1, ?ü}

  iex> "über" |> match(satisfy(&(&1 == ?β)))
  {:failure, "über", 0, {{:expected, "`β'"}, 0}}
  """
  defmacro satisfy(predicate, name \\ nil),
    do: Satisfy.compile(predicate, name, quote(do: c), quote(do: c :: utf8), Charset)
end
