defmodule ExParsers.Parse do
  @moduledoc """
  Entry-point functions for parsers.
  """
  use ExParsers.Types
  alias ExParsers.Error

  @spec parse(String.t(), parser(), parser()) :: {:ok, any()} | {:error, any()}
  @doc """
  Parse `input` using `parser`, and return {:ok, value} or {:error, message}.

  iex> "f" |> parse(one_of(:lower))
  {:ok, ?f}

  iex> "f" |> parse(one_of(:upper))
  {:error, "upper expected at 1:1"}
  """
  def parse(input, parser, k \\ ok()) do
    with {:failure, _, _, e} <- match(input, parser, k) do
      {:error, Error.full_message(e, input)}
    end
  end

  @spec match(String.t(), parser(), parser()) ::
          {:success | :failure, String.t(), integer(), any()}
  @doc """
  Match `input` using `parser`, and return a tuple representing the internal
  parse state following the match.

  iex> "foo" |> match(one_of(:lower))
  {:success, "oo", 1, ?f}

  iex> "foo" |> match(one_of(:upper))
  {:failure, "foo", 0, {{:expected, "upper"}, 0}}
  """
  def match(input, parser, k \\ succeed()), do: parser.(input, 0, nil, k)

  @spec ok :: parser()
  def ok(), do: fn _, _, v, _ -> {:ok, v} end

  @spec succeed :: parser()
  def succeed(), do: fn i, p, v, _ -> {:success, i, p, v} end
end
