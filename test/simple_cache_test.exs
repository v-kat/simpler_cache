defmodule SimpleCacheTest do
  use ExUnit.Case
  doctest SimpleCache

  test "greets the world" do
    assert SimpleCache.hello() == :world
  end
end
