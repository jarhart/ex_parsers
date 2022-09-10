defmodule ExParsers.Types do
  @spec __using__([]) :: Macro.t()
  defmacro __using__([]) do
    quote do
      @type parser() :: (String.t(), integer(), any(), parser() -> any())

      @type charset() :: ExParsers.Text.Charset.t()

      @type min_max() :: {integer(), integer() | nil} | {integer()} | Range.t()
    end
  end
end
