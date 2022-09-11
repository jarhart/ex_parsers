defmodule ExParsers.Combinators do
  @moduledoc """
  Parser combinators.
  """
  @spec __using__([]) :: Macro.t()
  defmacro __using__([]) do
    quote do
      require unquote(__MODULE__)
      import unquote(__MODULE__)
    end
  end

  @spec is_parser(term()) :: Macro.t()
  defguard is_parser(fun) when is_function(fun, 4)

  use ExParsers.Types

  import __MODULE__.MacroHelpers
  alias __MODULE__.{ChainLeft, ChainRight, ManyUntil, Prec, Reduce, Sep, SepEnd, SkipMany}
  alias ExParsers.Error
  import ExParsers.Parse

  @spec return(Macro.t()) :: Macro.t()
  @doc """
  Match as `value` without consuming input.

  iex> "foo" |> match(return(42))
  {:success, "foo", 0, 42}
  """
  defmacro return(value),
    do: quote(do: fn i, p, _, k -> k.(i, p, unquote(value), ok()) end)

  @spec pure(Macro.t()) :: Macro.t()
  @doc """
  Alias for `return`.
  """
  defmacro pure(value), do: quote(do: return(unquote(value)))

  @spec lookahead(Macro.t()) :: Macro.t()
  @doc """
  Zero-width positive lookahead. Match without consuming input when `parser`
  matches.

  iex> "foo" |> match(lookahead(char(?f)))
  {:success, "foo", 0, ?f}

  iex> "foo" |> match(skip_left(lookahead(char(?f)), many(any())))
  {:success, "", 3, 'foo'}

  iex> "boo" |> match(skip_left(lookahead(char(?f)), many(any())))
  {:failure, "boo", 0, {{:expected, "`f'"}, 0}}
  """
  defmacro lookahead(parser) do
    quote do
      fn i0, p0, v0, k ->
        unquote(parser).(i0, p0, v0, fn _, _, v, _ ->
          k.(i0, p0, v, ok())
        end)
      end
    end
  end

  @spec exclude(Macro.t()) :: Macro.t()
  @doc """
  Zero-width negative lookahead. Match without consuming input when `parser`
  fails.

  iex> "boo" |> match(skip_left(exclude(char(?f)), many(any())))
  {:success, "", 3, 'boo'}

  iex> "foo" |> match(skip_left(exclude(char(?f)), many(any())))
  {:failure, "foo", 0, {{:unexpected, "102"}, 0}}
  """
  defmacro exclude(parser) do
    quote do
      fn i, p, v, k ->
        case unquote(parser).(i, p, v, succeed()) do
          {:success, _, _, v} -> {:failure, i, p, {{:unexpected, inspect(v)}, p}}
          {:failure, _, _, _} -> k.(i, p, v, ok())
        end
      end
    end
  end

  @doc """
  Fail with `message`.

  iex> "foo" |> match(fail("bad!"))
  {:failure, "foo", 0, {"bad!", 0}}
  """
  @spec fail(Macro.t()) :: Macro.t()
  defmacro fail(content),
    do: quote(do: fn i, p, _, _ -> {:failure, i, p, {unquote(content), p}} end)

  @spec expected(Macro.t()) :: Macro.t()
  @doc """
  Fail with `{:expected, <value>}`.

  iex> "foo" |> parse(expected("`boo'"))
  {:error, "`boo' expected at 1:1"}

  iex> "foo" |> parse(expected(:boo))
  {:error, "boo expected at 1:1"}
  """
  defmacro expected(value), do: quote(do: fail({:expected, unquote(value)}))

  @spec unexpected(Macro.t()) :: Macro.t()
  @doc """
  Fail with `{:unexpected, <value>}`.

  iex> "foo" |> parse(unexpected("`foo'"))
  {:error, "unexpected `foo' at 1:1"}

  iex> "foo" |> parse(unexpected(:foo))
  {:error, "unexpected foo at 1:1"}
  """
  defmacro unexpected(value), do: quote(do: fail({:unexpected, unquote(value)}))

  @spec label(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  If parser fails, fail with `{:expected, label}`.

  iex> "foo" |> parse(string("bar") |> label("BAR"))
  {:error, "BAR expected at 1:1"}
  """
  defmacro label(label, do: parser) do
    quote do
      fn i, p, v, k ->
        with {:failure, _, _, {_, ep} = e} <- unquote(parser).(i, p, v, k),
             do: {:failure, i, p, (ep > p && e) || {{:expected, unquote(label)}, p}}
      end
    end
  end

  defmacro label(parser, label),
    do: quote(do: label(unquote(label), do: unquote(parser)))

  @spec seq(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match `left`, then `right` as a tuple.

  iex> "foo" |> match(seq(char(?f), char(?o)))
  {:success, "o", 2, {?f, ?o}}
  """
  defmacro seq(left, right),
    do: quote(do: ap(unquote(left), unquote(right), &{&1, &2}))

  @spec and_then(Macro.t(), Macro.t()) :: Macro.t()
  defmacro and_then(left, right),
    do: quote(do: seq(unquote(left), unquote(right)))

  @spec seq([Macro.t()]) :: Macro.t()
  @doc """
  Match with `parsers` in sequence as nested tuples.

  iex> "foo" |> match(seq([char(?f), char(?o), char(?o)]))
  {:success, "", 3, {{?f, ?o}, ?o}}

  iex> "foo" |> match(seq({char(?f), char(?o), char(?o)}))
  {:success, "", 3, {?f, ?o, ?o}}
  """
  defmacro seq(do: {:__block__, _, parsers}),
    do: assoc_l(parsers, &quote(do: seq(unquote(&1), unquote(&2))))

  defmacro seq(parsers) when is_list(parsers),
    do: assoc_l(parsers, &quote(do: seq(unquote(&1), unquote(&2))))

  defmacro seq({left, right}), do: quote(do: seq(unquote(left), unquote(right)))

  defmacro seq({:{}, _, parsers}) when length(parsers) > 2,
    do: quote(do: ap(unquote([quote(do: return({})) | parsers]), &Tuple.append(&1, &2)))

  @spec cons(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match `head`, then `tail` as `[head | tail]`.

  iex> "foo" |> match(cons(char(?f), many(char(?o))))
  {:success, "", 3, 'foo'}
  """
  defmacro cons(head, tail),
    do: quote(do: ap(unquote(head), unquote(tail), &[&1 | &2]))

  @spec concat(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match `left`, then `right` as `left ++ right`.

  iex> "aaabbcc" |> match(concat(many(char(?a)), many(char(?b))))
  {:success, "cc", 5, 'aaabb'}
  """
  defmacro concat(l, r), do: quote(do: ap(unquote(l), unquote(r), &++/2))

  @spec concat([Macro.t()]) :: Macro.t()
  defmacro concat(do: {:__block__, _, parsers}),
    do: assoc_l(parsers, &quote(do: concat(unquote(&1), unquote(&2))))

  defmacro concat(parsers) when is_list(parsers),
    do: assoc_l(parsers, &quote(do: concat(unquote(&1), unquote(&2))))

  @spec sconcat(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match `left`, then `right` as `left <> right`.

  iex> "foobar" |> match(sconcat(string("foo"), string("bar")))
  {:success, "", 6, "foobar"}
  """
  defmacro sconcat(l, r), do: quote(do: ap(unquote(l), unquote(r), &<>/2))

  @spec sconcat([Macro.t()]) :: Macro.t()
  defmacro sconcat(do: {:__block__, _, parsers}),
    do: assoc_l(parsers, &quote(do: sconcat(unquote(&1), unquote(&2))))

  defmacro sconcat(parsers) when is_list(parsers),
    do: assoc_l(parsers, &quote(do: sconcat(unquote(&1), unquote(&2))))

  @spec scons(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match `c`, then `s` and prepend `c` to `s`.

  iex> "foo" |> match(scons(char(?f), string("oo")))
  {:success, "", 3, "foo"}
  """
  defmacro scons(c, s),
    do: quote(do: ap(unquote(c), unquote(s), &(<<&1>> <> &2)))

  @spec sappend(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match `s`, then `c` and append `c` to `s`.

  iex> "foo" |> match(sappend(string("fo"), char(?o)))
  {:success, "", 3, "foo"}
  """
  defmacro sappend(s, c),
    do: quote(do: ap(unquote(s), unquote(c), &(&1 <> <<&2>>)))

  @spec ap(Macro.t(), Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match `left`, then `right` as `fun.(left, right)`

  iex> "foobar" |> match(ap(string("foo"), string("bar"), &[&2, &1]))
  {:success, "", 6, ["bar", "foo"]}
  """
  defmacro ap(l, r, fun) do
    quote do
      fn i0, p0, v0, k ->
        unquote(l).(i0, p0, v0, fn i1, p1, v1, _ ->
          unquote(r).(i1, p1, v1, fn i2, p2, v2, k2 ->
            k.(i2, p2, unquote(compile_call(fun, quote(do: v1), quote(do: v2))), k2)
          end)
        end)
      end
    end
  end

  @spec ap(Macro.t(), Macro.t()) :: Macro.t()
  defmacro ap(fun, do: {:__block__, _, parsers}),
    do: assoc_l(parsers, &quote(do: ap(unquote_splicing([&1, &2, fun]))))

  defmacro ap(parsers, fun) when is_list(parsers),
    do: assoc_l(parsers, &quote(do: ap(unquote_splicing([&1, &2, fun]))))

  @spec skip_left(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match `left`, then `right` and discard the result from `left`.

  iex> "foobar" |> match(skip_left(string("foo"), string("bar")))
  {:success, "", 6, "bar"}

  iex> "foobar" |> match(skip_left(string("foo"), string("bar")) |> map(&String.to_atom/1))
  {:success, "", 6, :bar}
  """
  defmacro skip_left(l, r) do
    quote do
      fn i0, p0, v0, k ->
        unquote(l).(i0, p0, v0, fn i1, p1, v1, _ ->
          unquote(r).(i1, p1, v1, k)
        end)
      end
    end
  end

  @spec skip(Macro.t(), Macro.t()) :: Macro.t()
  defmacro skip(parser, do: k), do: quote(do: skip_left(unquote(parser), unquote(k)))
  defmacro skip(parser, k), do: quote(do: skip_left(unquote(parser), unquote(k)))

  @spec skip_right(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match `left`, then `right` and discard the result from `right`.

  iex> "foobar" |> match(skip_right(string("foo"), string("bar")))
  {:success, "", 6, "foo"}
  """
  defmacro skip_right(l, r),
    do: quote(do: ap(unquote(l), unquote(r), fn l, _ -> l end))

  @doc """
  Match `pre`, `parser`, and `post` and discard `pre` and `post`.

  iex> "(foo)" |> match(skip_around(string("("), string("foo"), string(")")))
  {:success, "", 5, "foo"}
  """
  @spec skip_around(Macro.t(), Macro.t(), Macro.t()) :: Macro.t()
  defmacro skip_around(pre, parser, post),
    do: quote(do: skip_right(skip_left(unquote(pre), unquote(parser)), unquote(post)))

  @doc """
  Match `pre`, `parser`, and `post` and discard `pre` and `post`.

  iex> "(foo)" |> match(between(string("("), string(")"), string("foo")))
  {:success, "", 5, "foo"}

  iex> "(bar)" |> match(between string("("), string(")"), do: string("bar"))
  {:success, "", 5, "bar"}
  """
  @spec between(Macro.t(), Macro.t(), Macro.t()) :: Macro.t()
  defmacro between(pre, post, do: parser),
    do: quote(do: skip_around(unquote_splicing([pre, parser, post])))

  defmacro between(pre, post, parser),
    do: quote(do: between(unquote(pre), unquote(post), do: unquote(parser)))

  @spec alt(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match `left`, or match `right` if matching `left` fails.

  iex> "foo" |> match(alt(string("foo"), string("bar")))
  {:success, "", 3, "foo"}

  iex> "bar" |> match(alt(string("foo"), string("bar")))
  {:success, "", 3, "bar"}

  iex> "baz" |> match(alt(string("foo"), string("bar")))
  {:failure, "baz", 0, {{:expected, "`foo' or `bar'"}, 0}}
  """
  defmacro alt(left, right) do
    quote do
      fn i0, p0, v0, k ->
        with {:failure, _, _, e0} <- unquote(left).(i0, p0, v0, k),
             {:failure, _, _, e1} <- unquote(right).(i0, p0, v0, k),
             do: {:failure, i0, p0, unquote(Error).alt(e0, e1)}
      end
    end
  end

  @spec alt([Macro.t()]) :: Macro.t()
  @doc """
  Try each parser in order until one matches.

  iex> "baz" |> match(alt([string("foo"), string("bar"), string("baz")]))
  {:success, "", 3, "baz"}
  """
  defmacro alt(do: {:__block__, _, parsers}),
    do: assoc_l(parsers, &quote(do: alt(unquote(&1), unquote(&2))))

  defmacro alt(parsers),
    do: assoc_l(parsers, &quote(do: alt(unquote(&1), unquote(&2))))

  @spec or_else(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match `left`, or `right` if matching `left` fails.

  iex> "foo" |> match(string("foo") |> or_else(string("bar")))
  {:success, "", 3, "foo"}

  iex> "bar" |> match(string("foo") |> or_else(string("bar")))
  {:success, "", 3, "bar"}

  iex> "baz" |> match(string("foo") |> or_else(string("bar")))
  {:failure, "baz", 0, {{:expected, "`foo' or `bar'"}, 0}}
  """
  defmacro or_else(left, right), do: quote(do: alt(unquote(left), unquote(right)))

  @spec maybe(Macro.t()) :: Macro.t()
  @doc """
  Match `parser` as a singleton list, or an empty list if `parser` fails.

  iex> "foo" |> match(maybe(string("foo")))
  {:success, "", 3, ["foo"]}

  iex> "bar" |> match(maybe do: string("foo"))
  {:success, "bar", 0, []}
  """
  defmacro maybe(do: parser) do
    quote do
      fn i, p, v, k ->
        with {:failure, _, _, _} <-
               unquote(parser).(i, p, v, fn i1, p1, v, _ ->
                 k.(i1, p1, [v], ok())
               end),
             do: k.(i, p, [], k)
      end
    end
  end

  defmacro maybe(parser), do: quote(do: maybe(do: unquote(parser)))

  @spec string_of(Macro.t()) :: Macro.t()
  @doc """
  Match `parser`, which should return `chardata`, repeatedly, and return a
  string.

  iex> "foobar" |> match(string_of(any()))
  {:success, "", 6, "foobar"}

  iex> "foobar" |> match(string_of(alt(string("foo"), string("bar"))))
  {:success, "", 6, "foobar"}

  iex> "foo42" |> match(string_of(:alpha))
  {:success, "42", 3, "foo"}

  iex> "foo42" |> match(string_of(?a..?z))
  {:success, "42", 3, "foo"}

  iex> "foo42" |> match(string_of('of'))
  {:success, "42", 3, "foo"}
  """
  defmacro string_of(name) when is_atom(name), do: quote(do: string_of(one_of(unquote(name))))
  defmacro string_of({:.., _, [_, _]} = range), do: quote(do: string_of(one_of(unquote(range))))
  defmacro string_of(do: parser), do: quote(do: string_of(unquote(parser), {0, nil}))
  defmacro string_of([_ | _] = list), do: quote(do: string_of(one_of(unquote(list))))
  defmacro string_of(parser), do: quote(do: string_of(do: unquote(parser)))

  @spec string_of(Macro.t(), Macro.t()) :: Macro.t()
  defmacro string_of(min_max, do: parser) do
    quote do
      map(
        many(unquote(parser), unquote(normalize_min_max(min_max))),
        &IO.chardata_to_string/1
      )
    end
  end

  defmacro string_of(parser, min_max),
    do: quote(do: string_of(unquote(min_max), do: unquote(parser)))

  @spec many(Macro.t()) :: Macro.t()
  @doc """
  Match `term` repeatedly as a list.

  iex> "aaabb" |> match(many(char(?a)))
  {:success, "bb", 3, 'aaa'}

  iex> "aaabb" |> match(many(char(?a), {0, 2}))
  {:success, "abb", 2, 'aa'}

  iex> "aaabb" |> match(many(char(?a), 0..2))
  {:success, "abb", 2, 'aa'}

  iex> "aaabb" |> match(many(char(?a), max: 2))
  {:success, "abb", 2, 'aa'}

  iex> "aaabb" |> match(many(char(?a), {2}))
  {:success, "abb", 2, 'aa'}
  """
  defmacro many(do: term), do: quote(do: many({0, nil}, do: unquote(term)))

  defmacro many(term), do: quote(do: many(do: unquote(term)))

  @spec many(Macro.t(), Macro.t()) :: Macro.t()
  defmacro many(min_max, do: term) do
    quote do
      reverse(reduce(unquote(term), [], &[&1 | &2], unquote(normalize_min_max(min_max))))
    end
  end

  defmacro many(term, min_max), do: quote(do: many(unquote(min_max), do: unquote(term)))

  @spec many1(Macro.t()) :: Macro.t()
  defmacro many1(do: term), do: quote(do: many1(nil, do: unquote(term)))

  defmacro many1(term), do: quote(do: many1(do: unquote(term)))

  @spec many1(Macro.t(), Macro.t()) :: Macro.t()
  defmacro many1(max, do: term), do: quote(do: many(unquote(term), {1, unquote(max)}))

  defmacro many1(term, max), do: quote(do: many1(unquote(max), do: unquote(term)))

  @spec many_until(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match `term` zero or more times, as a list, until `end_parser` succeeds.

  iex> "aaaaaab" |> match(many_until(any(), char(?b)))
  {:success, "", 7, 'aaaaaa'}

  iex> "aaaaaab" |> match(many_until(any(), lookahead(char(?b))))
  {:success, "b", 6, 'aaaaaa'}
  """
  defmacro many_until(end_parser, do: term),
    do: quote(do: unquote(ManyUntil).start(unquote(term), unquote(end_parser)))

  defmacro many_until(term, end_parser),
    do: quote(do: many_until(unquote(end_parser), do: unquote(term)))

  @spec until(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match `term` zero or more times, as a list, until `end_parser` succeeds.

  iex> "aaabbb" |> match(until char(?b), do: any())
  {:success, "bb", 4, 'aaa'}
  """
  defmacro until(end_parser, do: term),
    do: quote(do: many_until(unquote(end_parser), do: unquote(term)))

  @spec skip_many(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Skip `left` as many times as it matches before matching `right`.

  iex> "   foo" |> match(skip_many(string(" "), string("foo")))
  {:success, "", 6, "foo"}

  iex> "   bar" |> match(skip_many(string(" "), do: string("bar")))
  {:success, "", 6, "bar"}
  """
  defmacro skip_many(left, right \\ quote(do: e()))

  defmacro skip_many(left, do: right),
    do: quote(do: unquote(SkipMany).start(unquote(left), unquote(right)))

  defmacro skip_many(left, right),
    do: quote(do: skip_many(unquote(left), do: unquote(right)))

  @spec reduce(Macro.t(), Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match `term` repeatedly

  iex> "foo" |> match(reduce(any(), "", &(&2 <> <<&1>>)))
  {:success, "", 3, "foo"}
  """
  defmacro reduce(z, fun, do: term),
    do: quote(do: reduce(unquote_splicing([term, z, fun, {0, nil}])))

  defmacro reduce(term, z, fun), do: quote(do: reduce(unquote_splicing([term, z, fun, {0, nil}])))

  @spec reduce(Macro.t(), Macro.t(), Macro.t(), Macro.t()) :: Macro.t()
  defmacro reduce(z, fun, min_max, do: term) do
    quote do
      unquote(Reduce).start(
        unquote(term),
        unquote(z),
        unquote(fun),
        unquote(normalize_min_max(min_max))
      )
    end
  end

  defmacro reduce(term, z, fun, min_max) do
    quote do
      reduce(unquote(z), unquote(fun), unquote(normalize_min_max(min_max)), do: unquote(term))
    end
  end

  @spec sep(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match zero or more occurrences of `term` separated by `sep`, as a list.

  iex> "a,b,c,d" |> match(sep(one_of(?a..?z), string(",")))
  {:success, "", 7, 'abcd'}

  iex> "" |> match(sep(one_of(?a..?z), string(",")))
  {:success, "", 0, []}

  iex> "a,b,c,d," |> match(sep(one_of(?a..?z), string(",")))
  {:failure, "a,b,c,d,", 0, {{:unexpected, :EOF}, 8}}
  """
  defmacro sep(sep, do: term),
    do: quote(do: unquote(Sep).sep(unquote(term), unquote(sep)))

  defmacro sep(term, sep),
    do: quote(do: sep(unquote(sep), do: unquote(term)))

  @spec sep1(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match one or more occurrences of `term` separated by `sep`, as a list.

  iex> "a,b,c,d" |> match(sep1(one_of(?a..?z), string(",")))
  {:success, "", 7, 'abcd'}

  iex> "" |> match(sep1(one_of(?a..?z), string(",")))
  {:failure, "", 0, {{:unexpected, :EOF}, 0}}

  iex> "a,b,c,d," |> match(sep1(one_of(?a..?z), string(",")))
  {:failure, "a,b,c,d,", 0, {{:unexpected, :EOF}, 8}}
  """
  defmacro sep1(sep, do: term),
    do: quote(do: unquote(Sep).sep1(unquote(term), unquote(sep)))

  defmacro sep1(term, sep),
    do: quote(do: sep1(unquote(sep), do: unquote(term)))

  @spec sep_end(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match zero or more occurrences of `term` separated and optionally terminated
  by `sep`, as a list.

  iex> "a,b,c,d" |> match(sep_end(one_of(?a..?z), string(",")))
  {:success, "", 7, 'abcd'}

  iex> "" |> match(sep_end(one_of(?a..?z), string(",")))
  {:success, "", 0, []}

  iex> "a,b,c,d," |> match(sep_end(one_of(?a..?z), string(",")))
  {:success, "", 8, 'abcd'}
  """
  defmacro sep_end(sep, do: term),
    do: quote(do: unquote(SepEnd).sep(unquote(term), unquote(sep)))

  defmacro sep_end(term, sep),
    do: quote(do: sep_end(unquote(sep), do: unquote(term)))

  @spec sep_end1(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match one or more occurrences of `term` separated and optionally terminated
  by `sep`, as a list.

  iex> "a,b,c,d" |> match(sep_end1(one_of(?a..?z), string(",")))
  {:success, "", 7, 'abcd'}

  iex> "" |> match(sep_end1(one_of(?a..?z), string(",")))
  {:failure, "", 0, {{:unexpected, :EOF}, 0}}

  iex> "a,b,c,d," |> match(sep_end1(one_of(?a..?z), string(",")))
  {:success, "", 8, 'abcd'}
  """
  defmacro sep_end1(sep, do: term),
    do: quote(do: unquote(SepEnd).sep1(unquote(term), unquote(sep)))

  defmacro sep_end1(term, sep),
    do: quote(do: sep_end1(unquote(sep), do: unquote(term)))

  @spec chain_left(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match one or more occurrences of `term`, separated by `op` and applies the
  value of `op` to the term values, associating to the left.

  iex> op = char(?,) |> as(&[&1, &2])
  iex> "a,b,c" |> match(chain_left(any(), op))
  {:success, "", 5, ['ab', ?c]}

  iex> op = char(?,) |> as(&[&1, &2])
  iex> "a,b,c," |> match(chain_left(any(), op))
  {:failure, "a,b,c,", 0, {{:unexpected, :EOF}, 6}}
  """
  defmacro chain_left(op, do: term),
    do: quote(do: unquote(ChainLeft).start(unquote(term), unquote(op)))

  defmacro chain_left(term, op),
    do: quote(do: chain_left(unquote(op), do: unquote(term)))

  @spec chain_right(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match one or more occurrences of `term`, separated by `op` and applies the
  value of `op` to the term values, associating to the left.

  iex> op = char(?,) |> as(&[&1, &2])
  iex> "a,b,c" |> match(chain_right(any(), op))
  {:success, "", 5, [?a, 'bc']}

  iex> op = char(?,) |> as(&[&1, &2])
  iex> "a,b,c," |> match(chain_right(any(), op))
  {:failure, "a,b,c,", 0, {{:unexpected, :EOF}, 6}}
  """
  defmacro chain_right(op, do: term),
    do: quote(do: unquote(ChainRight).start(unquote(term), unquote(op)))

  defmacro chain_right(term, op),
    do: quote(do: chain_right(unquote(op), do: unquote(term)))

  @spec map(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match `parser` and apply `fun` to the value.

  iex> "42" |> match(many(one_of(:digit)) |> map(&List.to_integer/1))
  {:success, "", 2, 42}

  iex> "42" |> match(many(one_of(:digit)) |> map({List, :to_integer, []}))
  {:success, "", 2, 42}

  iex> "20" |> match(many(one_of(:digit)) |> map({List, :to_integer, [16]}))
  {:success, "", 2, 32}

  iex> "42" |> match(many(one_of(:digit)) |> map(List.to_integer()))
  {:success, "", 2, 42}

  iex> "20" |> match(many(one_of(:digit)) |> map(List.to_integer(16)))
  {:success, "", 2, 32}
  """
  defmacro map(parser, fun) do
    quote do
      fn i0, p0, v0, k ->
        unquote(parser).(i0, p0, v0, fn i, p, v, _ ->
          k.(i, p, unquote(compile_call(fun, quote(do: v))), ok())
        end)
      end
    end
  end

  @spec prefix(any(), integer(), f | nil) :: parser() | {:unary, integer(), f}
        when f: (any() -> any())
  def prefix(op, precedence, fun \\ nil)

  def prefix(op, precedence, fun) when is_parser(op),
    do: map(op, {Prec, :prefix, [precedence, fun]})

  def prefix(op, precedence, fun), do: Prec.prefix(op, precedence, fun)

  @spec postfix(any(), integer(), f | nil) :: parser() | {:unary, integer(), f}
        when f: (any() -> any())
  def postfix(op, precedence, fun \\ nil)

  def postfix(op, precedence, fun) when is_parser(op),
    do: map(op, {Prec, :postfix, [precedence, fun]})

  def postfix(op, precedence, fun), do: Prec.postfix(op, precedence, fun)

  @spec infix_left(any(), integer(), f | nil) :: parser() | {:binary, {integer(), integer()}, f}
        when f: (any(), any() -> any())
  def infix_left(op, precedence, fun \\ nil)

  def infix_left(op, precedence, fun) when is_parser(op),
    do: map(op, {Prec, :infix_left, [precedence, fun]})

  def infix_left(op, precedence, fun), do: Prec.infix_left(op, precedence, fun)

  @spec infix_right(any(), integer(), f | nil) :: parser() | {:binary, {integer(), integer()}, f}
        when f: (any(), any() -> any())
  def infix_right(op, precedence, fun \\ nil)

  def infix_right(op, precedence, fun) when is_parser(op),
    do: map(op, {Prec, :infix_right, [precedence, fun]})

  def infix_right(op, precedence, fun), do: Prec.infix_right(op, precedence, fun)

  @spec prec(parser(), parser(), integer()) :: parser()
  defdelegate prec(term, op, min_bp \\ 0), to: Prec

  @spec tag(x, atom()) :: x when x: parser() | any()
  @doc """
  Match `parser` and return a tuple of `tag` and the result.

  iex> "foo" |> match(many(one_of(:alnum)) |> tag(:ident))
  {:success, "", 3, {:ident, 'foo'}}
  """
  def tag(parser, tag) when is_parser(parser), do: map(parser, &tag(&1, tag))

  def tag(x, tag), do: {tag, x}

  @spec reverse(Macro.t()) :: Macro.t()
  @doc """
  Match `parser` which should return a list, and return the list reversed.

  iex> "foo" |> match(many(any()) |> reverse())
  {:success, "", 3, 'oof'}
  """
  defmacro reverse(parser), do: quote(do: map(unquote(parser), &Enum.reverse/1))

  @spec as(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match `parser` and return `value`.

  iex> "true" |> match(string("true") |> as(true))
  {:success, "", 4, true}
  """
  defmacro as(parser, value) do
    quote do
      fn i0, p0, v0, k ->
        unquote(parser).(i0, p0, v0, fn i1, p1, _, _ ->
          k.(i1, p1, unquote(value), ok())
        end)
      end
    end
  end

  @spec filter(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match `parser` if applying `fun` to the returned value returns `true`.

  iex> "foo" |> match(many(any()) |> filter(&(&1 == 'foo')))
  {:success, "", 3, 'foo'}

  iex> "foo" |> match(many(any()) |> filter(&(&1 == 'boo')))
  {:failure, "foo", 0, {"`foo' failed predicate", 0}}
  """
  defmacro filter(parser, fun) do
    quote do
      fn i0, p0, v0, k ->
        unquote(parser).(i0, p0, v0, fn i, p, v, _ ->
          if unquote(compile_call(fun, quote(do: v))) do
            k.(i, p, v, ok())
          else
            {:failure, i0, p0, {"`#{v}' failed predicate", p0}}
          end
        end)
      end
    end
  end

  @spec bind(Macro.t(), Macro.t()) :: Macro.t()
  @doc """
  Match `parser` and apply `fun` to the value to get another parser, than match
  that parser.

  iex> "aaaabb" |> match(lookahead(any()) |> bind(fn c -> many(char(c)) end))
  {:success, "bb", 4, 'aaaa'}
  """
  defmacro bind(parser, fun) do
    quote do
      fn i0, p0, v0, k ->
        unquote(parser).(i0, p0, v0, fn i, p, v, _ ->
          unquote(compile_call(fun, quote(do: v))).(i, p, v0, k)
        end)
      end
    end
  end

  @spec parse_with(String.t() | atom(), fun()) :: parser()
  @doc """
  Match using a function that takes a binary string and returns a tuple of the
  parsed value and the unparsed portion of the string.

  iex> "423foo" |> match(parse_with("Integer", &Integer.parse/1))
  {:success, "foo", 3, 423}
  """
  def parse_with(name, fun) do
    fn i, p, _, k ->
      case fun.(i) do
        {:error, message} ->
          {:failure, i, p, {message, p}}

        {value, remainder} ->
          k.(remainder, p + String.length(i) - String.length(remainder), value, ok())

        _ ->
          {:failure, i, p, {{:expected, name}, p}}
      end
    end
  end

  @spec parse_as(module(), String.t() | atom() | nil) :: parser()
  @doc """
  Match using the `parse/1` function of `module`.

  iex> "423foo" |> match(parse_as(Integer))
  {:success, "foo", 3, 423}
  """
  def parse_as(module, name \\ nil) do
    parse_with(name || List.last(Module.split(module)), &module.parse/1)
  end
end
