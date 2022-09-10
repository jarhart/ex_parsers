defmodule ExParsers.Text.Utf32 do
  @moduledoc """
  Text parsing primitives for text encoded as UTF-32.
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
  Match any UTF-32 character.
  """
  defmacro any(), do: Any.compile(quote(do: c), quote(do: c :: utf32))

  @spec char(Macro.t()) :: Macro.t()
  @doc """
  Match an exact UTF-32 character.
  """
  defmacro char(c) when is_integer(c), do: Char.compile(c, quote(do: unquote(c) :: utf32))

  defmacro char([c]) when is_integer(c), do: quote(do: char(unquote(c)))

  defmacro char(<<c::utf32>>), do: quote(do: char(unquote(c)))

  defmacro char(c), do: quote(do: satisfy(&(&1 == unquote(c)), "`#{[unquote(c)]}'"))

  @spec one_of(charset()) :: Macro.t()
  @doc """
  Match any single UTF-32 character in `chars`. The argument can be a character
  list, a character range, an atom with a character class name, or a list of
  any of these.
  """
  defmacro one_of(chars), do: OneOf.compile(chars, quote(do: c), quote(do: c :: utf32), Charset)

  @spec none_of(charset()) :: Macro.t()
  @doc """
  Match any single UTF-32 character not in `chars`. The argument can be a
  character list, a character range, an atom with a character class name, or a
  list of any of these.
  """
  defmacro none_of(chars), do: NoneOf.compile(chars, quote(do: c), quote(do: c :: utf32), Charset)

  @spec satisfy(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match any single UTF-32 character for which `predicate` returns `true`.
  """
  defmacro satisfy(predicate, name \\ nil),
    do: Satisfy.compile(predicate, name, quote(do: c), quote(do: c :: utf32), Charset)
end
