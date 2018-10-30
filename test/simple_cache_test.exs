defmodule SimplerCacheTest do
  use ExUnit.Case
  use PropCheck

  @table_name Application.get_env(:simpler_cache, :cache_name, :simpler_cache)
  @global_ttl_ms Application.get_env(:simpler_cache, :global_ttl_ms, 10_000)
  @global_ttl_s round(@global_ttl_ms / 1000)
  @expiry_buffer_s round(@global_ttl_s / 5)

  setup do
    :ets.delete_all_objects(@table_name)
    :ok
  end

  @tag timeout: 105_000
  property "Set ttl guarantees key dies after x time", numtests: 120 do
    forall {key, val, timer_ttl_ms} <- {term(), term(), integer(1, 100_000)} do
      {:ok, :inserted} = SimplerCache.insert_new(key, val)
      {:ok, :updated} = SimplerCache.set_ttl_ms(key, timer_ttl_ms)
      :timer.sleep(timer_ttl_ms + 10)
      equals(SimplerCache.get(key), nil)
    end
  end

  property "Set ttl and expires always equal", numtests: 20 do
    forall {key, val, timer_ttl_ms} <- {term(), term(), integer(5_000, 100_000_000)} do
      {:ok, :inserted} = SimplerCache.put(key, val)
      {:ok, :updated} = SimplerCache.set_ttl_ms(key, timer_ttl_ms)
      unix_now = DateTime.utc_now() |> DateTime.to_unix()
      expire_at = :ets.lookup_element(@table_name, key, 4)
      equals(expire_at - unix_now + @expiry_buffer_s, round(timer_ttl_ms / 1000))
    end
  end

  property "doesnt explode on ttl set with missing item", numtests: 5 do
    forall {key, timer_ttl_ms} <- {term(), integer(101, :inf)} do
      equals({:error, :element_not_found}, SimplerCache.set_ttl_ms(key, timer_ttl_ms))
    end
  end

  property "insert new doesnt insert if item exists already", numtests: 5 do
    forall {key, val} <- {term(), term()} do
      :ets.delete_all_objects(@table_name)
      {:ok, :inserted} = SimplerCache.insert_new(key, val)
      equals({:error, :item_is_in_cache}, SimplerCache.insert_new(key, :new_val))
    end
  end

  property "update_existing eventually updates with high contention", numtests: 20 do
    forall {key, update_fn} <- {term(), function(1, term())} do
      contender_val = :something
      delay = 1
      {:ok, :inserted} = SimplerCache.put(key, contender_val)
      {:ok, contender_1} = :timer.apply_interval(delay, SimplerCache, :put, [key, contender_val])

      {:ok, contender_2} =
        :timer.apply_interval(delay + 1, SimplerCache, :put, [key, contender_val])

      :timer.sleep(delay)

      equals({:ok, :updated}, SimplerCache.update_existing(key, update_fn))
      equals({:ok, :cancel}, :timer.cancel(contender_1))
      equals({:ok, :cancel}, :timer.cancel(contender_2))
    end
  end

  property "get_or_store eventually updates with high contention", numtests: 20 do
    forall {key, fallback_fn} <- {term(), function(0, term())} do
      contender_val = :something
      delay = 1
      {:ok, contender_1} = :timer.apply_interval(delay, SimplerCache, :put, [key, contender_val])

      {:ok, contender_2} =
        :timer.apply_interval(delay + 1, SimplerCache, :put, [key, contender_val])

      :timer.sleep(delay)

      new_val = fallback_fn.()
      equals(new_val, SimplerCache.get_or_store(key, fallback_fn))
      equals({:ok, :cancel}, :timer.cancel(contender_1))
      equals({:ok, :cancel}, :timer.cancel(contender_2))
    end
  end

  property "get for not inserted keys works", numtests: 5 do
    forall {key} <- {term()} do
      equals(nil, SimplerCache.get(key))
    end
  end

  property "get_or_store fix works correctly", numtests: 5 do
    forall {key, val, fallback_fn} <- {term(), term(), function(0, term())} do
      {:ok, :inserted} = SimplerCache.put(key, val)
      new_tll_ms = 100
      SimplerCache.set_ttl_ms(key, new_tll_ms)
      :timer.sleep(round(new_tll_ms / 6))
      equals(fallback_fn.(), SimplerCache.get_or_store(key, fallback_fn))
    end
  end
end
