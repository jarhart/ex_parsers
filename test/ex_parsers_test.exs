defmodule ExParsersTest do
  use ExUnit.Case
  doctest ExParsers

  test "greets the world" do
    assert ExParsers.hello() == :world
  end
end
