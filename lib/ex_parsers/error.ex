defmodule ExParsers.Error do
  @moduledoc """
  Error types and helper functions.
  """
  @type t() :: {content(), integer()}
  @type content() :: String.t() | {:expected, String.t()} | {:unexpected, String.t()}

  @spec alt(t(), t()) :: t()
  def alt({{:expected, v0}, p}, {{:expected, v1}, p}), do: {{:expected, "#{v0} or #{v1}"}, p}
  def alt({_, p0} = e0, {_, p1} = e1), do: p0 > p1 && e0 || e1

  @spec message(content()) :: String.t()
  def message({:expected, value}), do: "#{value} expected"
  def message({:unexpected, value}), do: "unexpected #{value}"
  def message(s) when is_binary(s), do: s

  @spec full_message(t(), String.t(), keyword()) :: String.t()
  def full_message({content, p}, source, opts \\ []) do
    {line, col} = full_position(source, p, opts)
    "#{message(content)} at #{line + 1}:#{col + 1}"
  end

  @spec full_position(String.t(), integer(), keyword()) :: {integer(), integer()}
  def full_position(source, position, opts \\ []) when is_integer(position) do
    stream_lines(source)
    |> Enum.reduce_while({0, position}, fn line, {line_num, col_num} ->
      case String.length(line) do
        len when len < col_num -> {:cont, {line_num + 1, col_num - len - 1}}
        _ -> {:halt, {line_num, adjust_for_tabs(col_num, line, opts[:tab_size] || 8)}}
      end
    end)
  end

  @spec stream_lines(String.t()) :: Enum.t()
  defp stream_lines(source) do
    Stream.unfold(source, fn s ->
      case String.split(s, "\n", parts: 2) do
        [l, r] -> {l, r}
        _ -> nil
      end
    end)
  end

  defp adjust_for_tabs(col_num, line, tab_size) do
    String.graphemes(line)
    |> Enum.take(col_num)
    |> Enum.reduce(0, fn
      "\t", acc -> tab_size * div(acc + tab_size, tab_size)
      _, acc -> acc + 1
    end)
  end
end
