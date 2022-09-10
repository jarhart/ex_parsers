defmodule ExParsers.Text.Character.Any do
  @moduledoc false

  @spec compile(Macro.t(), Macro.t()) :: Macro.t()
  def compile(var, pattern) do
    quote do
      fn
        <<unquote(pattern), rest::binary>>, p, _, k -> k.(rest, p + 1, unquote(var), ok())
        i, p, _, _ -> {:failure, i, p, {{:unexpected, :EOF}, p}}
      end
    end
  end
end
