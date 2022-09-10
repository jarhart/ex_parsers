defmodule ExParsers.Combinators.Reduce do
  @moduledoc """
  Looping function for `reduce`.
  """
  use ExParsers.Types
  import ExParsers.Parse

  def start(term, z, fun, min_max) do
    fn i0, p0, _, k ->
      loop(i0, p0, z, term, fun, min_max, k)
    end
  end

  def start(term, fun, min_max) do
    fn i0, p0, z, k ->
      loop(i0, p0, z, term, fun, min_max, k)
    end
  end

  defp loop(i0, p0, acc, term, fun, {min, max}, k) when max > 0 do
    case term.(i0, p0, nil, succeed()) do
      {:success, i, p, v} when p > p0 ->
        loop(i, p, fun.(v, acc), term, fun, next_min_max({min, max}), k)

      failure when min > 0 ->
        failure

      _ ->
        k.(i0, p0, acc, ok())
    end
  end

  defp loop(i, p, acc, _, _, _, k), do: k.(i, p, acc, ok())

  defp next_min_max({min, nil}), do: {min - 1, nil}
  defp next_min_max({min, max}), do: {min - 1, max - 1}
end

defmodule ExParsers.Combinators.ManyUntil do
  @moduledoc """
  Looping function for `many_util`.
  """
  use ExParsers.Types
  import ExParsers.Parse

  @spec start(parser(), parser()) :: parser()
  def start(term, end_parser) do
    fn i, p, _, k ->
      loop(i, p, [], term, end_parser, fn i, p, acc, _ ->
        k.(i, p, Enum.reverse(acc), ok())
      end)
    end
  end

  defp loop(i0, p0, acc, term, end_parser, k) do
    with {:failure, _, _, _} <-
           end_parser.(i0, p0, nil, fn i, p, _, _ ->
             k.(i, p, acc, ok())
           end) do
      case term.(i0, p0, nil, succeed()) do
        {:success, i, p, v} when p > p0 -> loop(i, p, [v | acc], term, end_parser, k)
        _ -> k.(i0, p0, acc, ok())
      end
    end
  end
end

defmodule ExParsers.Combinators.SkipMany do
  @moduledoc """
  Looping function for `skip_many`.
  """
  use ExParsers.Types
  import ExParsers.Parse

  @spec start(parser(), parser()) :: parser()
  def start(left, right) do
    fn i, p, _, k ->
      loop(i, p, left, right, k)
    end
  end

  defp loop(i0, p0, left, right, k) do
    case left.(i0, p0, nil, succeed()) do
      {:success, i, p, _} when p > p0 -> loop(i, p, left, right, k)
      _ -> right.(i0, p0, nil, k)
    end
  end
end
