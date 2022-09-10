defmodule ExParsers.Text.Character.NoneOf do
  @moduledoc false

  @spec compile(Macro.t(), Macro.t(), Macro.t(), module()) :: Macro.t()
  def compile(chars, var, pattern, charset) do
    quote do
      fn
        "", p, _, _ ->
          {:failure, "", p, {{:unexpected, :EOF}, p}}

        <<unquote(pattern), rest::binary>>, p, _, k
        when unquote(charset.negative_guard(charset.new(chars), var)) ->
          k.(rest, p + 1, unquote(var), ok())

        i, p, _, _ ->
          {:failure, i, p, {{:expected, unquote(expectation(chars, charset))}, p}}
      end
    end
  end

  defp expectation(name, _) when is_atom(name), do: "not #{name}"
  defp expectation([name], _) when is_atom(name), do: "not #{name}"
  defp expectation([i], _) when is_integer(i), do: "not `#{[i]}'"
  defp expectation([{i, i}], _), do: "not `#{[i]}'"
  defp expectation(chars, charset), do: "none of #{charset.show_quoted(chars)}"
end
