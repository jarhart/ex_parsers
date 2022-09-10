defmodule ExParsers.Combinators.SepEnd do
  @moduledoc """
  Looping function for `sep_end`.
  """
  use ExParsers.Types
  import ExParsers.Parse

  @spec sep(parser(), parser()) :: parser()
  def sep(term, sep) do
    fn i0, p0, _, k ->
      loop(i0, p0, [], term, sep, false, k)
    end
  end

  @spec sep1(parser(), parser()) :: parser()
  def sep1(term, sep) do
    fn i0, p0, _, k ->
      loop(i0, p0, [], term, sep, true, k)
    end
  end

  defp loop(i0, p0, acc, term, sep, req, k) do
    case term.(i0, p0, nil, succeed()) do
      {:success, i1, p1, v} ->
        case sep.(i1, p1, nil, succeed()) do
          {:success, i2, p2, _} -> loop(i2, p2, [v | acc], term, sep, false, k)
          _ -> k.(i1, p1, Enum.reverse([v | acc]), ok())
        end

      _ when not req ->
        k.(i0, p0, Enum.reverse(acc), ok())

      failure ->
        failure
    end
  end
end
