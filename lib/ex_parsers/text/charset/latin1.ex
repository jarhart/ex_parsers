defmodule ExParsers.Text.Charset.Latin1 do
  @moduledoc """
  Defines the Latin1 (ISO-8859-1) 8-bit character set with POSIX character
  class names.
  """
  use ExParsers.Text.Charset, range: 0..0xFF
  import ExParsers.IntSet, only: [insert: 2, new: 1, union: 2]

  @digit new(?0..?9)
  @lower new(?a..?z)
  @upper new(?A..?Z)
  @alpha union(@lower, @upper)
  @alnum union(@alpha, @digit)

  @posix %{
    alnum: @alnum,
    alpha: @alpha,
    ascii: new(0..0x7F),
    blank: new(' \t'),
    cntrl: new([0x00..0x1F, 0x7F]),
    digit: @digit,
    graph: new(0x21..0x7E),
    lower: @lower,
    print: new(0x20..0x7E),
    punct: new('-!"#$%&\'()*+,./:;<=>?@[\\]^_`{|}~'),
    space: new(' \t\r\n\v\f'),
    upper: @upper,
    word: insert(@alnum, ?_),
    xdigit: new([?A..?F, ?a..?f, ?0..?9])
  }

  @impl true
  @spec named_charsets() :: %{atom() => t()}
  def named_charsets(), do: @posix
end
