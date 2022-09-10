defmodule ExParsers.Text.Character.Char do
  @moduledoc false

  @spec compile(Macro.t(), Macro.t()) :: Macro.t()
  def compile(c, pattern) when is_integer(c) do
    quote do
      fn
        <<unquote(pattern), rest::binary>>, p, v, k ->
          k.(rest, p + 1, unquote(c), ok())

        i, p, _, _ ->
          {:failure, i, p, {{:expected, unquote("`#{[c]}'")}, p}}
      end
    end
  end
end
