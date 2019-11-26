defmodule SimplerCache do
  @moduledoc """
  Simple cache implementation with no complicated features or locks.
  """
  @table_name Application.get_env(:simpler_cache, :cache_name, :simpler_cache)
  @global_ttl_ms Application.get_env(:simpler_cache, :global_ttl_ms, 10_000)

  @type update_function :: (any -> any)
  @type fallback_function :: (() -> any)

  @compile {:inline,
            get: 1, put: 2, insert_new: 2, delete: 1, size: 0, set_ttl_ms: 2, expiry_buffer_ms: 1}

  @doc "Returns an item from cache or nil if not found"
  @spec get(any) :: nil | any
  def get(key) do
    maybe_tuple =
      :ets.lookup(@table_name, key)
      |> List.first()

    # the schema for items is {key, value, timer_reference, expiry_ms, ttl_ms}
    case maybe_tuple do
      item when is_tuple(item) ->
        elem(item, 1)

      _ ->
        nil
    end
  end

  @doc "Inserts new item or overwrites old item's value"
  @spec put(any, any, pos_integer) :: {:ok, :inserted} | {:error, any}
  def put(key, value, ttl_ms \\ @global_ttl_ms) when is_integer(ttl_ms) and ttl_ms > 0 do
    with {:ok, t_ref} <- :timer.apply_after(ttl_ms, :ets, :delete, [@table_name, key]),
         expiry = :erlang.monotonic_time(:millisecond) + ttl_ms - expiry_buffer_ms(ttl_ms),
         true <- :ets.insert(@table_name, {key, value, t_ref, expiry, ttl_ms}) do
      {:ok, :inserted}
    else
      {:error, err} -> {:error, err}
    end
  end

  @doc "Inserts new item into cache"
  @spec insert_new(any, any, pos_integer) ::
          {:ok, :inserted} | {:error, :item_is_in_cache} | {:error, any}
  def insert_new(key, value, ttl_ms \\ @global_ttl_ms) when is_integer(ttl_ms) and ttl_ms > 0 do
    case :timer.apply_after(ttl_ms, :ets, :delete, [@table_name, key]) do
      {:ok, t_ref} ->
        expiry = :erlang.monotonic_time(:millisecond) + ttl_ms - expiry_buffer_ms(ttl_ms)

        case :ets.insert_new(@table_name, {key, value, t_ref, expiry, ttl_ms}) do
          true ->
            {:ok, :inserted}

          false ->
            :timer.cancel(t_ref)
            {:error, :item_is_in_cache}
        end

      {:error, err} ->
        {:error, err}
    end
  end

  @doc "Deletes item from cache or does no-op"
  @spec delete(any) :: {:ok, :deleted} | {:ok, :not_found}
  def delete(key) do
    case :ets.take(@table_name, key) do
      [] ->
        {:ok, :not_found}

      [{_k, _v, t_ref, _expiry, _ttl_ms} | _] ->
        :timer.cancel(t_ref)
        {:ok, :deleted}
    end
  end

  @doc """
  Updates existing value in cache based on old value and resets the timer
  Warning the below may retry a bit on heavy contention
  """
  @spec update_existing(any, update_function) :: {:ok, :updated} | {:error, :failed_to_find_entry}
  def update_existing(key, passed_fn) when is_function(passed_fn, 1) do
    with [{key, old_val, t_ref, _expiry, _ttl_ms} | _] <- :ets.take(@table_name, key),
         :timer.cancel(t_ref),
         {:ok, :inserted} <- SimplerCache.insert_new(key, passed_fn.(old_val)) do
      {:ok, :updated}
    else
      [] -> {:error, :failed_to_find_entry}
      _ -> update_existing(key, passed_fn)
    end
  end

  @doc """
  Gets or stores an item based on a passed in function
  if the item is near expiry it will also update the cache and ttl to avoid thundering herd issues
  """
  @warming_key "__SIMPLER_CACHE_WARMING_SENTINEL_KEY__"
  @spec get_or_store(any, fallback_function, pos_integer) :: any
  def get_or_store(key, fallback_fn, ttl_ms \\ @global_ttl_ms)
      when is_integer(ttl_ms) and ttl_ms > 0 and is_function(fallback_fn, 0) do
    with [] <- :ets.lookup(@table_name, key),
         {:ok, :inserted} <- SimplerCache.insert_new(@warming_key, "", round(ttl_ms / 2)),
         new_val = fallback_fn.(),
         {:ok, _any} <- SimplerCache.delete(@warming_key),
         {:ok, :inserted} <- SimplerCache.insert_new(key, new_val, ttl_ms) do
      new_val
    else
      [{@warming_key, _val, _t_ref, _expiry, _found_ttl_ms} | _] ->
        sleep_time = round(ttl_ms / 10)
        Process.sleep(sleep_time)
        get_or_store(key, fallback_fn, ttl_ms)

      [{key, val, t_ref, expiry, found_ttl_ms} | _] ->
        expires_in = expiry - :erlang.monotonic_time(:millisecond)

        if expires_in <= 0 do
          case SimplerCache.set_ttl_ms(key, 2 * expiry_buffer_ms(found_ttl_ms)) do
            {:ok, :updated} ->
              new_val = fallback_fn.()
              {:ok, :inserted} = SimplerCache.put(key, new_val, ttl_ms)
              :timer.cancel(t_ref)
              new_val

            {:error, _} ->
              val
          end
        else
          val
        end

      {:error, _reason} ->
        get_or_store(key, fallback_fn, ttl_ms)
    end
  end

  @doc "Returns the number of elements in the cache"
  @spec size() :: non_neg_integer
  def size() do
    :ets.info(@table_name, :size)
  end

  @doc "Sets the ttl to a specific value in ms greater than 0 for an item"
  @spec set_ttl_ms(any, pos_integer) ::
          {:ok, :updated}
          | {:error, :failed_to_update_element}
          | {:error, :element_not_found}
          | {:error, any}
  def set_ttl_ms(key, time_ms) when is_integer(time_ms) and time_ms > 0 do
    try do
      t_ref = :ets.lookup_element(@table_name, key, 3)
      :timer.cancel(t_ref)

      case :timer.apply_after(time_ms, :ets, :delete, [@table_name, key]) do
        {:ok, new_t_ref} ->
          with expiry =
                 :erlang.monotonic_time(:millisecond) + time_ms - expiry_buffer_ms(time_ms),
               true <- :ets.update_element(@table_name, key, {4, expiry}),
               true <- :ets.update_element(@table_name, key, {3, new_t_ref}),
               true <- :ets.update_element(@table_name, key, {5, time_ms}) do
            {:ok, :updated}
          else
            false ->
              :timer.cancel(new_t_ref)
              {:error, :failed_to_update_element}
          end

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      ArgumentError ->
        {:error, :element_not_found}
    end
  end

  defp expiry_buffer_ms(ttl), do: round(ttl / 5)
end
