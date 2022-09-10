defmodule ExParsers.Text.Character.Satisfy do
  @moduledoc false

  alias ExParsers.Text.Character.OneOf

  @spec compile(Macro.t(), Macro.t(), Macro.t(), Macro.t(), module()) :: Macro.t()
  def compile(predicate, name, var, pattern, charset) do
    if combinator?(predicate) do
      compile_static(elem(Code.eval_quoted(predicate), 0), name, var, pattern, charset)
    else
      compile_dynamic(predicate, name, var, pattern)
    end
  end

  defp compile_static(fun, name, var, pattern, charset),
    do: OneOf.compile(charset.build(fun), var, pattern, charset, name)

  defp compile_dynamic(quoted_fun, name, var, pattern) do
    quote do
      fn
        "", p, _, _ ->
          {:failure, "", p, {{:unexpected, :EOF}, p}}

        <<unquote(pattern), rest::binary>> = i, p, _, k ->
          if unquote(quoted_fun).(unquote(var)) do
            k.(rest, p + 1, unquote(var), ok())
          else
            {:failure, i, p, {unquote(error_content(name, quote(do: "`#{[unquote(var)]}'"))), p}}
          end
      end
    end
  end

  defp error_content(nil, actual), do: {:unexpected, actual}

  defp error_content(name, _), do: {:expected, name}

  defp combinator?({:&, _, [{:/, _, [_, _]}]}), do: true

  defp combinator?(expr), do: Enum.empty?(free_vars(expr))

  defp free_vars({:&, _, body}), do: vars_in(body)

  defp free_vars({:fn, _, [{:->, _, [args, body]}]}),
    do: MapSet.difference(vars_in(body), vars_in(args))

  defp vars_in(expr) do
    Macro.postwalk(expr, MapSet.new(), fn
      {name, _, module} = e, s when is_atom(name) and is_atom(module) -> {e, MapSet.put(s, e)}
      e, s -> {e, s}
    end)
    |> elem(1)
  end
end
