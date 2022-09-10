defmodule ExParsers.Text do
  @moduledoc """
  Text parsing primitives.
  """

  @spec __using__([]) :: Macro.t()
  defmacro __using__([]) do
    quote do
      require unquote(__MODULE__)
      import unquote(__MODULE__)
    end
  end

  # @spec e() :: parser()
  @doc """
  Always match as an empty list without consuming input.

  iex> "foo" |> match(e())
  {:success, "foo", 0, []}
  """
  defmacro e(), do: quote(do: fn i, p, _, k -> k.(i, p, [], ok()) end)

  # @spec eof() :: parser()
  @doc """
  Match if there is no more input.

  iex> "" |> match(eof())
  {:success, "", 0, nil}

  iex> "foo" |> match(eof())
  {:failure, "foo", 0, {{:expected, :EOF}, 0}}
  """
  defmacro eof() do
    quote do
      fn
        "", p, v, k -> k.("", p, v, ok())
        i, p, _, _ -> {:failure, i, p, {{:expected, :EOF}, p}}
      end
    end
  end

  @spec string(String.t()) :: Macro.t()
  @doc """
  Match an exact string.

  iex> "foo" |> match(string("foo"))
  {:success, "", 3, "foo"}

  iex> "übermensch" |> match(string("über"))
  {:success, "mensch", 4, "über"}

  iex> "boo" |> match(string("foo"))
  {:failure, "boo", 0, {{:expected, "`foo'"}, 0}}
  """
  defmacro string(s) do
    quote do
      fn
        unquote(s) <> rest, p, v, k ->
          k.(rest, p + unquote(String.length(s)), unquote(s), ok())

        i, p, _, _ ->
          {:failure, i, p, {{:expected, unquote("`#{s}'")}, p}}
      end
    end
  end
end
