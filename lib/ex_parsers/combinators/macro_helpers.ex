defmodule ExParsers.Combinators.MacroHelpers do
  @moduledoc false

  @spec compile_call(Macro.t(), Macro.t()) :: Macro.t()
  def compile_call({:{}, _, [{:__aliases__, _, [_ | _]} = mod, name, args]}, v)
      when is_atom(name) and is_list(args),
      do: quote(do: unquote(mod).unquote(name)(unquote_splicing([v | args])))

  def compile_call({name, args}, v) when is_atom(name) and is_list(args),
    do: quote(do: unquote(name)(unquote_splicing([v | args])))

  def compile_call({:&, _, [{:/, _, [call, 1]}]}, v), do: Macro.pipe(v, call, 0)

  def compile_call({:&, _, args} = fun, v) when is_list(args),
    do: quote(do: unquote(fun).(unquote(v)))

  def compile_call({:fn, _, [{:->, _, _} | _]} = fun, v), do: quote(do: unquote(fun).(unquote(v)))

  def compile_call(fun, v), do: Macro.pipe(v, fun, 0)

  @spec compile_call(Macro.t(), Macro.t(), Macro.t()) :: Macro.t()
  def compile_call({:{}, _, [{:__aliases__, _, [_ | _]} = mod, name, args]}, v1, v2)
      when is_atom(name) and is_list(args),
      do: quote(do: unquote(mod).unquote(name)(unquote_splicing([v1, v2 | args])))

  def compile_call({name, args}, v1, v2) when is_atom(name) and is_list(args),
    do: quote(do: unquote(name)(unquote_splicing([v1, v2 | args])))

  def compile_call({:&, _, [{:/, _, [{name, m, _} = call, 2]}]}, v1, v2) do
    if is_atom(name) and Macro.operator?(name, 2) do
      {name, m, [v1, v2]}
    else
      Macro.pipe(v1, Macro.pipe(v2, call, 0), 0)
    end
  end

  def compile_call({:&, _, args} = fun, v1, v2) when is_list(args),
    do: quote(do: unquote(fun).(unquote(v1), unquote(v2)))

  def compile_call({:fn, _, [{:->, _, _} | _]} = fun, v1, v2),
    do: quote(do: unquote(fun).(unquote(v1), unquote(v2)))

  def compile_call(fun, v1, v2), do: Macro.pipe(v1, Macro.pipe(v2, fun, 0), 0)

  @spec assoc_l(nonempty_list(Macro.t()), (Macro.t(), Macro.t() -> Macro.t())) :: Macro.t()
  def assoc_l([l, r], fun), do: fun.(l, r)
  def assoc_l([l, r | rest], fun), do: assoc_l([fun.(l, r) | rest], fun)

  @spec normalize_min_max(Macro.t()) :: Macro.t()
  def normalize_min_max({:.., _, [min, {:-, _, [1]}]}), do: {min, nil}
  def normalize_min_max({:.., _, [min, max]}), do: {min, max}
  def normalize_min_max({:{}, _, [n]}), do: {n, n}
  def normalize_min_max(min) when is_integer(min), do: {min, nil}
  def normalize_min_max(min_max) when is_list(min_max), do: {min_max[:min] || 0, min_max[:max]}
  def normalize_min_max(min_max), do: min_max
end
