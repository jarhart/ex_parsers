defmodule ExParsers.Combinators.Prec do
  @moduledoc """
  Precedence climbing algorithm for `prec`. Supports infix, prefix, and postfix
  operators.
  """
  use ExParsers.Types
  import ExParsers.Parse

  @spec prefix(term(), integer(), f | nil) :: {:unary, integer(), f} when f: (any() -> any())
  def prefix(op, precedence, fun),
    do: {:unary, precedence * 2, unary_fun(op, fun)}

  @spec postfix(term(), integer(), f | nil) :: {:unary, integer(), f} when f: (any() -> any())
  def postfix(op, precedence, fun),
    do: {:unary, precedence * 2 - 1, unary_fun(op, fun)}

  @spec infix_left(term(), integer(), f | nil) :: {:binary, {integer(), integer()}, f}
        when f: (any(), any() -> any())
  def infix_left(op, precedence, fun),
    do: {:binary, {precedence * 2 - 1, precedence * 2}, binary_fun(op, fun)}

  @spec infix_right(term(), integer(), f | nil) :: {:binary, {integer(), integer()}, f}
        when f: (any(), any() -> any())
  def infix_right(op, precedence, fun),
    do: {:binary, {precedence * 2, precedence * 2 - 1}, binary_fun(op, fun)}

  @spec prefix(integer(), f | nil) :: (any() -> {:unary, integer(), f}) when f: (any() -> any())
  def prefix(precedence, fun \\ nil),
    do: &{:unary, precedence * 2, unary_fun(&1, fun)}

  @spec postfix(integer(), f | nil) :: (any() -> {:unary, integer(), f}) when f: (any() -> any())
  def postfix(precedence, fun \\ nil),
    do: &{:unary, precedence * 2 - 1, unary_fun(&1, fun)}

  @spec infix_left(integer(), f | nil) :: (any() -> {:binary, {integer(), integer()}, f})
        when f: (any(), any() -> any())
  def infix_left(precedence, fun \\ nil),
    do: &{:binary, {precedence * 2 - 1, precedence * 2}, binary_fun(&1, fun)}

  @spec infix_right(integer(), f | nil) :: (any() -> {:binary, {integer(), integer()}, f})
        when f: (any(), any() -> any())
  def infix_right(precedence, fun \\ nil),
    do: &{:binary, {precedence * 2, precedence * 2 - 1}, binary_fun(&1, fun)}

  @spec prec(parser(), parser(), integer()) :: parser()
  def prec(term, op, min_bp \\ 0) do
    fn i0, p0, _, k ->
      term.(i0, p0, nil, fn
        i, p, {:unary, bp, fun}, _ ->
          prec(term, op, bp).(i, p, nil, fn i, p, v, _ ->
            loop(i, p, fun.(v), term, op, min_bp, k)
          end)

        i, p, v, _ ->
          loop(i, p, v, term, op, min_bp, k)
      end)
    end
  end

  defp loop(i0, p0, l_val, term, op, min_bp, k) do
    case op.(i0, p0, nil, succeed()) do
      {:success, i, p, {:unary, bp, fun}} when bp >= min_bp ->
        loop(i, p, fun.(l_val), term, op, min_bp, k)

      {:success, i, p, {:binary, {l_bp, r_bp}, fun}} when l_bp >= min_bp ->
        prec(term, op, r_bp).(i, p, nil, fn i, p, r_val, _ ->
          loop(i, p, fun.(l_val, r_val), term, op, min_bp, k)
        end)

      _ ->
        k.(i0, p0, l_val, ok())
    end
  end

  defp unary_fun(op, fun), do: fun || (&{op, [&1]})

  defp binary_fun(op, fun), do: fun || (&{op, [&1, &2]})
end
