defmodule ExParsers.Combinators.ChainRight do
  @moduledoc """
  Looping function for `chain_right`.
  """
  use ExParsers.Types
  import ExParsers.Parse

  @spec start(parser(), parser()) :: parser()
  def start(term, op) do
    fn i0, p0, _, k ->
      with {:failure, _, _, e} <-
             term.(i0, p0, nil, fn i, p, v, _ ->
               loop(i, p, [v], term, op, k)
             end) do
        {:failure, i0, p0, e}
      end
    end
  end

  defp loop(i0, p0, acc, term, op, k) do
    case op.(i0, p0, nil, succeed()) do
      {:success, i1, p1, fun} ->
        with {:success, i2, p2, v} <- term.(i1, p1, nil, succeed()),
             do: loop(i2, p2, [{fun, v} | acc], term, op, k)

      _ ->
        k.(i0, p0, Enum.reduce(acc, &reducer/2), ok())
    end
  end

  defp reducer({next_fun, l_val}, {fun, r_val}), do: {next_fun, fun.(l_val, r_val)}
  defp reducer(l_val, {fun, r_val}), do: fun.(l_val, r_val)
end
