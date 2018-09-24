defmodule SimplerCacheTest do
  use ExUnit.Case
  use PropCheck

  @tag timeout: 105_000
  property "Set ttl guarantees key dies after x time", numtests: 120 do
    forall {key, val, timer_ttl_ms} <- {term(), term(), integer(101, 100_000)} do
      {:ok, :inserted} = SimplerCache.insert_new(key, val)
      {:ok, :updated} = SimplerCache.set_ttl_ms(key, timer_ttl_ms)
      :timer.sleep(timer_ttl_ms + 5)
      SimplerCache.get(key) == nil
    end
  end
end
