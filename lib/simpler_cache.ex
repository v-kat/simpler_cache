defmodule SimplerCache do
  @moduledoc """
  Simple cache implementation with no locks or other more complicated features.
  """
  @table_name Application.get_env(:simpler_cache, :cache_name, :simpler_cache)
  @global_ttl_ms Application.get_env(:simpler_cache, :global_ttl_ms, 10_000)
  @type update_function :: (any -> any)
  @type fallback_function :: (() -> any)

  @doc "Returns an item from cache or nil if not found"
  @spec get(any) :: nil | any
  def get(key) do
    maybe_tuple =
      :ets.lookup(@table_name, key)
      |> List.first()

    case maybe_tuple do
      item when is_tuple(item) ->
        elem(item, 1)

      _ ->
        nil
    end
  end

  @doc "Inserts new item or overwrites old item's value"
  @spec put(any, any) :: {:ok, :inserted} | {:error, any}
  def put(key, value) do
    with {:ok, t_ref} <- :timer.apply_after(@global_ttl_ms, :ets, :delete, [@table_name, key]),
         :ets.insert(@table_name, {key, value, t_ref}) do
      {:ok, :inserted}
    else
      {:error, err} -> {:error, err}
    end
  end

  @doc "Inserts new item into cache"
  @spec insert_new(any, any) :: {:ok, :inserted} | {:error, :item_is_in_cache} | {:error, any}
  def insert_new(key, value) do
    case :timer.apply_after(@global_ttl_ms, :ets, :delete, [@table_name, key]) do
      {:ok, t_ref} ->
        case :ets.insert_new(@table_name, {key, value, t_ref}) do
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

      [{_k, _v, t_ref} | _] ->
        :timer.cancel(t_ref)
        {:ok, :deleted}
    end
  end

  @doc """
  Updates existing value in cache based on old value
  Warning the below may retry a bit on heavy contention
  """
  @spec update_existing(any, update_function) :: {:ok, :updated} | {:error, :failed_to_find_entry}
  def update_existing(key, passed_fn) when is_function(passed_fn, 1) do
    with [{key, old_val, _timer} | _] <- :ets.take(@table_name, key),
         {:ok, :inserted} <- SimplerCache.insert_new(key, passed_fn.(old_val)) do
      {:ok, :updated}
    else
      [] -> {:error, :failed_to_find_entry}
      _ -> update_existing(key, passed_fn)
    end
  end

  @doc """
  Gets or stores an item based on a passed in function
  Warning the below may retry a bit on heavy contention
  """
  @spec get_or_store(any, fallback_function) :: any
  def get_or_store(key, passed_fn) when is_function(passed_fn, 0) do
    with [] <- :ets.lookup(@table_name, key),
         new_val = passed_fn.(),
         {:ok, :inserted} <- SimplerCache.insert_new(key, new_val) do
      new_val
    else
      [{_key, val, _timer} | _] ->
        val

      {:error, _reason} ->
        get_or_store(key, passed_fn)
    end
  end

  @doc "Returns the number of elements in the cache"
  @spec size() :: non_neg_integer
  def size() do
    :ets.info(@table_name, :size)
  end

  @doc "Sets the ttl to a specific value in ms over 100 for an item"
  @spec set_ttl_ms(any, pos_integer) ::
          {:ok, :updated} | {:error, :failed_to_update_element} | {:error, any}
  def set_ttl_ms(key, time_ms) when time_ms > 100 do
    t_ref = :ets.lookup_element(@table_name, key, 3)
    :timer.cancel(t_ref)

    case :timer.apply_after(time_ms, :ets, :delete, [@table_name, key]) do
      {:ok, new_t_ref} ->
        case :ets.update_element(@table_name, key, {3, new_t_ref}) do
          true ->
            {:ok, :updated}

          false ->
            :timer.cancel(new_t_ref)
            {:error, :failed_to_update_element}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
