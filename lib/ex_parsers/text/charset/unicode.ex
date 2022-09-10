defmodule ExParsers.Text.Charset.Unicode do
  @moduledoc """
  Defines the Unicode character set with Unicode category names and POSIX
  character class names.
  """
  use ExParsers.Text.Charset, range: 0..0x10FFFF
  import ExParsers.IntSet, only: [complement: 2, insert: 2, new: 1, union: 2]
  import Unicode.GeneralCategory, only: [categories: 0]

  @category_long_names %{
    C: :other,
    Cc: :control,
    Cf: :format,
    Cn: :unassigned,
    Co: :private_use,
    Cs: :surrogate,
    L: :letter,
    Ll: :lowercase_letter,
    Lm: :modifier_letter,
    Lo: :other_letter,
    Lt: :titlecase_letter,
    Lu: :uppercase_letter,
    M: :mark,
    Mc: :spacing_mark,
    Me: :enclosing_mark,
    Mn: :non_spacing_mark,
    N: :number,
    Nd: :decimal_number,
    Nl: :letter_number,
    No: :other_number,
    P: :punctuation,
    Pc: :connector_punctuation,
    Pd: :dash_punctuation,
    Pe: :close_punctuation,
    Pf: :final_punctuation,
    Pi: :initial_punctuation,
    Po: :other_punctuation,
    Ps: :open_punctuation,
    S: :symbol,
    Sc: :currency_symbol,
    Sk: :modifier_symbol,
    Sm: :mathematical_symbol,
    So: :other_symbol,
    Z: :separator,
    Zl: :line_separator,
    Zp: :paragraph_separator,
    Zs: :space_separator
  }

  @categories categories()
              |> Enum.map(fn {k, v} -> {@category_long_names[k], v} end)
              |> Enum.into(categories())

  @alpha @categories[:lowercase_letter]
         |> union(@categories[:uppercase_letter])
         |> union(@categories[:titlecase_letter])

  @posix %{
    alnum: @alpha |> union(@categories[:decimal_number]),
    alpha: @alpha,
    ascii: new(0..0x7F),
    blank: @categories[:space_separator] |> insert(?\t),
    cntrl: @categories[:control],
    digit: @categories[:decimal_number],
    graph: complement(union(@categories[:separator], @categories[:other]), @range),
    lower: @categories[:lowercase_letter],
    print: complement(@categories[:other], @range),
    punct: @categories[:punctuation] |> union(@categories[:symbol]),
    space: @categories[:separator] |> insert(' \t\r\n\v\f'),
    upper: @categories[:uppercase_letter],
    word:
      @categories[:letter]
      |> union(@categories[:number])
      |> union(@categories[:connector_punctuation]),
    xdigit: @categories[:decimal_number] |> insert([?A..?F, ?a..?f])
  }

  @named_charsets Map.merge(@categories, @posix)

  @impl true
  @spec named_charsets() :: %{atom() => t()}
  def named_charsets(), do: @named_charsets
end
