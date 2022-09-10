defmodule ExParsers do
  defmodule Latin1 do
    @moduledoc """
    Use `ExParsers.Latin1` to parse text as 8-bit characters with POSIX class
    names for named character sets.

    iex> use ExParsers.Latin1
    iex> "foo" |> match(one_of(:alpha))
    {:success, "oo", 1, ?f}

    iex> use ExParsers.Latin1
    iex> "über" |> match(any())
    {:success, <<188, ?b, ?e, ?r>>, 1, 195}
    """
    @spec __using__([]) :: Macro.t()
    defmacro __using__([]) do
      quote do
        use ExParsers.Text.Latin1
        import ExParsers.Parse
      end
    end
  end

  defmodule Utf8 do
    @moduledoc """
    Use `ExParsers.Utf8` to parse text as UTF-8 with Unicode categories and
    POSIX class names for named character sets.

    iex> use ExParsers.Utf8
    iex> "über" |> match(one_of(:Ll))
    {:success, "ber", 1, ?ü}

    iex> use ExParsers.Utf8
    iex> "über" |> match(one_of(:lowercase_letter))
    {:success, "ber", 1, ?ü}

    iex> use ExParsers.Utf8
    iex> "über" |> match(one_of(:lower))
    {:success, "ber", 1, ?ü}
    """
    @spec __using__([]) :: Macro.t()
    defmacro __using__([]) do
      quote do
        use ExParsers.Text.Utf8
        import ExParsers.Parse
      end
    end
  end

  defmodule Utf16 do
    @moduledoc """
    Use `ExParsers.Utf16` to parse text as UTF-16 with Unicode categories and
    POSIX class names for named character sets.
    """
    @spec __using__([]) :: Macro.t()
    defmacro __using__([]) do
      quote do
        use ExParsers.Text.Utf16
        import ExParsers.Parse
      end
    end
  end

  defmodule Utf32 do
    @moduledoc """
    Use `ExParsers.Utf32` to parse text as UTF-32 with Unicode categories and
    POSIX class names for named character sets.
    """
    @spec __using__([]) :: Macro.t()
    defmacro __using__([]) do
      quote do
        use ExParsers.Text.Utf32
        import ExParsers.Parse
      end
    end
  end
end
