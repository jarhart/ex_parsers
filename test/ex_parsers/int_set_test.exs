defmodule ExParsers.IntSetTest do
  use ExUnit.Case
  use ExUnitProperties
  alias ExParsers.IntSet
  doctest ExParsers.IntSet
  import StreamData

  @range 0..0xFF

  describe "new/1" do
    property "given a singleton range tuple returns it in a singleton list" do
      check all {min, max} <- range() do
        assert IntSet.new({min, max}) == [{min, max}]
      end
    end

    property "given a single integer creates a singleton range tuple" do
      check all i <- member() do
        assert IntSet.new(i) == [{i, i}]
      end
    end

    property "given a single range creates a singleton range tuple" do
      check all {min, max} <- range() do
        assert IntSet.new(min..max) == [{min, max}]
      end
    end

    property "given disjoint ranges creates a sorted range list" do
      check all {r1, r2} <- disjoint() do
        assert IntSet.new([r2, r1]) == [r1, r2]
      end
    end

    property "merges overlapping ranges" do
      check all {{min, _} = r1, {_, max} = r2} <- overlapping() do
        assert IntSet.new([r1, r2]) == [{min, max}]
      end
    end

    property "merges adjacent ranges" do
      check all {{min, _} = r1, {_, max} = r2} <- adjacent() do
        assert IntSet.new([r1, r2]) == [{min, max}]
      end
    end
  end

  describe "build/1" do
    property "given a single value predicate builds a singleton range tuple" do
      check all i <- member() do
        assert IntSet.build(@range, &(&1 == i)) == [{i, i}]
      end
    end

    property "given a range predicate builds a singleton range tuple" do
      check all {min, max} <- range() do
        assert IntSet.build(@range, &(&1 in min..max)) == [{min, max}]
      end
    end

    property "given a multi-range predicate builds a sorted range list" do
      check all {{min1, max1} = r1, {min2, max2} = r2} <- disjoint() do
        assert IntSet.build(@range, &(&1 in min1..max1 or &1 in min2..max2)) == [r1, r2]
      end
    end
  end

  describe "union/2" do
    property "merges disjoint sets" do
      check all {r1, r2} <- disjoint() do
        IntSet.union(IntSet.new(r2), IntSet.new(r1)) == [r1, r2]
      end
    end

    property "merges overlapping sets" do
      check all {{min, _} = r1, {_, max} = r2} <- overlapping() do
        assert IntSet.union(IntSet.new(r1), IntSet.new(r2)) == [{min, max}]
      end
    end

    property "merges adjacent sets" do
      check all {{min, _} = r1, {_, max} = r2} <- adjacent() do
        assert IntSet.union(IntSet.new(r1), IntSet.new(r2)) == [{min, max}]
      end
    end
  end

  describe "complement/2" do
    property "returns the complement of a set over a specified range" do
      check all s <- set(),
                c = IntSet.complement(s, @range),
                i <- member() do
        assert IntSet.member?(s, i) == not IntSet.member?(c, i)
      end
    end
  end

  defp set() do
    gen all bs <- list_of(boolean(), length: Enum.count(@range)) do
      IntSet.build(@range, &Enum.at(bs, &1))
    end
  end

  defp member(), do: integer(@range)

  defp range() do
    sorted_members(2) |> map(&List.to_tuple/1)
  end

  defp disjoint() do
    gen all [a, b, c, d] <- sorted_members(4), c > b + 1 do
      {{a, b}, {c, d}}
    end
  end

  defp overlapping() do
    gen all [a, b, c, d] <- sorted_members(4) do
      {{a, c}, {b, d}}
    end
  end

  defp adjacent() do
    gen all [a, b, c] <- sorted_members(3), c > b + 1 do
      {{a, b}, {b + 1, c}}
    end
  end

  defp sorted_members(n) do
    uniq_list_of(member(), length: n) |> map(&Enum.sort/1)
  end
end
