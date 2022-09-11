# ExParsers

A parser combinator library inspired by Haskell's Parsec and Scala's parser
combinators.

ExParsers aims to be a batteries-included parsing library that makes simple
parsing easy, and complex parsing possible.

## Usage

```elixir
iex> use ExParsers.Utf8
iex> "foo" |> parse(many(one_of(:letter)))
{:ok, 'foo'}
iex> "foo" |> parse(string_of(:letter))
{:ok, "foo"}
iex> "foobarbaz" |> parse(seq({string("foo"), string("bar"), string("baz")}))
{:ok, {"foo", "bar", "baz"}}
iex> "42" |> parse(many(one_of(:digit)) |> map(List.to_integer()))
{:ok, 42}
```

## Features

- Support for Latin1 and Unicode
- Operator precedence parsing
- Applicative and Monadic combinators
- Reasonable fast

## Examples

```elixir
defmodule Examples.Calc do
  use ExParsers.Latin1

  @spec calc(String.t()) :: {:ok, integer()} | {:error, any()}
  def calc(input), do: parse(input, full_expr())

  def full_expr(), do: expr() |> skip_right(skip_many(ws(), eof()))

  def expr(), do: prec(term(), op())

  def term() do
    skip_many ws() do
      alt do
        string("+")                             |> prefix(4, &(&1))
        string("-")                             |> prefix(4, &-/1)
        parse_as(Float)
        between(string("("), string(")"), expr())
      end
    end
  end

  def op() do
    skip_many ws() do
      alt do
        string("^")                             |> infix_right(4, &**/2)
        string("*")                             |> infix_left(3, &*/2)
        string("/")                             |> infix_left(3, &//2)
        string("+")                             |> infix_left(2, &+/2)
        string("-")                             |> infix_left(2, &-/2)
      end
    end
  end

  def ws(), do: one_of(:space)
end
```

```elixir
defmodule Examples.Json do
  use ExParsers.Utf8

  def parse_json(input), do: input |> parse(json())

  def json(), do: element() |> skip_right(eof())

  def value() do
    alt do
      object()
      array()
      string()
      number()
      string("true")                                |> as(true)
      string("false")                               |> as(false)
      string("null")                                |> as(nil)
    end
  end

  def object() do
    between char(?{), char(?}) do
      alt(members(), ws())                          |> map(Map.new())
    end
  end

  def members(), do: sep1(member(), char(?,))

  def member() do
    seq do
      skip_around(ws(), string(), ws())
      skip_left(char(?:), element())
    end
  end

  def array(), do: between(char(?[), char(?]), alt(elements(), ws()))

  def elements(), do: sep1(element(), char(?,))

  def element(), do: between(ws(), ws(), value())

  def string(), do: between(char(?"), char(?"), string_of(character()))

  def character() do
    alt do
      skip_left(char(?\\), escape())
      none_of('"')
    end
  end

  def escape() do
    any() |> bind(fn
      ?b -> return(?\b)
      ?f -> return(?\f)
      ?n -> return(?\n)
      ?r -> return(?\r)
      ?t -> return(?\t)
      ?u -> many(hex(), {4})                        |> map(List.to_integer(16))
      c -> return(c)
    end)
  end

  def hex(), do: one_of([?0..?9, ?A..?Z, ?a..?z])

  def number() do
    seq({integer(), fraction(), exponent()}) |> map(fn
      {i, [], e} -> List.to_integer(i ++ e)
      {i, [f], e} -> List.to_float(i ++ f ++ e)
    end)
  end

  def integer() do
    alt do
      cons(onenine(), digits())
      cons(digit(), e())
      cons(char(?-), cons(onenine(), digits()))
      cons(char(?-), cons(digit(), e()))
    end
  end

  def digits(), do: many1(digit())

  def digit(), do: one_of(?0..?9)

  def onenine(), do: one_of(?1..?9)

  def fraction(), do: maybe(cons(char(?.), digits()))

  def exponent(), do: maybe(cons(one_of('Ee'), concat(sign(), digits())))

  def sign(), do: maybe(one_of('+-'))

  def ws(), do: skip_many(one_of(' \t\n\r'))
end
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ex_parsers` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_parsers, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/ex_parsers>.
