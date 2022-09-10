defmodule ExParsers.Combinators.ChainLeft do
  @moduledoc """
  Looping function for `chain_left`.
  """
  use ExParsers.Types
  import ExParsers.Parse

  @spec start(parser(), parser()) :: parser()
  def start(term, op) do
    fn i0, p0, _, k ->
      with {:failure, _, _, e} <-
             term.(i0, p0, nil, fn i, p, v, _ ->
               loop(i, p, v, term, op, k)
             end) do
        {:failure, i0, p0, e}
      end
    end
  end

  defp loop(i0, p0, v0, term, op, k) do
    case op.(i0, p0, nil, succeed()) do
      {:success, i1, p1, fun} ->
        with {:success, i2, p2, v1} <- term.(i1, p1, nil, succeed()),
             do: loop(i2, p2, fun.(v0, v1), term, op, k)

      _ ->
        k.(i0, p0, v0, ok())
    end
  end
end
