defmodule ExParsers.Combinators.Sep do
  @moduledoc """
  Looping function for `sep`.
  """
  use ExParsers.Types
  import ExParsers.Parse

  @spec sep(parser(), parser()) :: parser()
  def sep(term, sep) do
    fn i0, p0, _, k ->
      case term.(i0, p0, nil, succeed()) do
        {:success, i, p, v} ->
          with {:failure, _, _, e} <- loop(i, p, [v], term, sep, k), do: {:failure, i0, p0, e}

        {:failure, _, _, _} ->
          k.(i0, p0, [], ok())
      end
    end
  end

  @spec sep1(parser(), parser()) :: parser()
  def sep1(term, sep) do
    fn i0, p0, _, k ->
      with {:failure, _, _, e} <-
             term.(i0, p0, nil, fn i, p, v, _ ->
               loop(i, p, [v], term, sep, k)
             end) do
        {:failure, i0, p0, e}
      end
    end
  end

  defp loop(i0, p0, acc, term, sep, k) do
    case sep.(i0, p0, nil, succeed()) do
      {:success, i1, p1, _} ->
        with {:success, i2, p2, v} <- term.(i1, p1, nil, succeed()),
             do: loop(i2, p2, [v | acc], term, sep, k)

      _ ->
        k.(i0, p0, Enum.reverse(acc), ok())
    end
  end
end
