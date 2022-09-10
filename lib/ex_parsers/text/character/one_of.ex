defmodule ExParsers.Text.Character.OneOf do
  @moduledoc false

  @spec compile(Macro.t(), Macro.t(), Macro.t(), module(), String.t() | nil) :: Macro.t()
  def compile(chars, var, pattern, charset, name \\ nil) do
    quote do
      fn
        "", p, _, _ ->
          {:failure, "", p, {{:unexpected, :EOF}, p}}

        <<unquote(pattern), rest::binary>>, p, _, k
        when unquote(charset.positive_guard(charset.new(chars), var)) ->
          k.(rest, p + 1, unquote(var), ok())

        i, p, _, _ ->
          {:failure, i, p, {{:expected, unquote(name || expectation(chars, charset))}, p}}
      end
    end
  end

  defp expectation(name, _) when is_atom(name), do: "#{name}"
  defp expectation([name], _) when is_atom(name), do: "#{name}"
  defp expectation([i], _) when is_integer(i), do: "`#{[i]}'"
  defp expectation([{i, i}], _), do: "`#{[i]}'"
  defp expectation(chars, charset), do: "one of #{charset.show_quoted(chars)}"
end
