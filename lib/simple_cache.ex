defmodule SimpleCache do
  @moduledoc """
  Simple cache implementation with no locks or other more complicated features.
  """
  @table_name Application.get_env(:simple_cache, :cache_name, :simple_cache)
  @global_ttl_ms Application.get_env(:simple_cache, :global_ttl_ms, 10_000)

  @spec get(any) :: nil | any
  def get(key) do
    :ets.lookup(@table_name, key) |> List.first()
  end

  @doc """
  Inserts item or overwrites it
  """
  @spec put(any, any) :: {:ok, :inserted} | {:error, term}
  def put(key, value) do
    with {:ok, t_ref} <- :timer.apply_after(@global_ttl_ms, :ets, :delete, [@table_name, key]),
         :ets.insert(@table_name, {key, value, t_ref}) do
      {:ok, :inserted}
    else
      {:error, err} -> {:error, err}
    end
  end

  @doc """
  Inserts new item into cache
  """
  @spec insert_new(any, any) :: {:ok, :inserted} | {:error, :item_is_in_cache} | {:error, term}
  def insert_new(key, value) do
    with {:ok, t_ref} <- :timer.apply_after(@global_ttl_ms, :ets, :delete, [@table_name, key]),
         true <- :ets.insert_new(@table_name, {key, value, t_ref}) do
      {:ok, :inserted}
    else
      {:error, err} -> {:error, err}
      false -> {:error, :item_is_in_cache}
    end
  end

  @doc """
  Deletes item from cache returns ok if doesn't exist as well
  """
  @spec delete(any) :: true
  def delete(key) do
    t_ref = :ets.lookup_element(@table_name, key, 3)
    :timer.cancel(t_ref)
    :ets.delete(@table_name, key)
  end

  @doc """
  Updates existing value in cache based on old value
  Warning the below may retry a bit on heavy contention
  """
  @spec update_existing(any, function) :: {:ok, :updated} | {:error, :failed_to_find_entry}
  def update_existing(key, passed_fn) when is_function(passed_fn) do
    with [{key, old_val, _timer}] <- :ets.take(@table_name, key),
         {:ok, :inserted} <- SimpleCache.insert_new(key, passed_fn.(old_val)) do
      {:ok, :updated}
    else
      [] -> {:error, :failed_to_find_entry}
      _ -> get_or_store(key, passed_fn)
    end
  end

  @doc """
  Gets or stores an item based on a passed in function
  Warning the below may retry a bit on heavy contention
  """
  @spec get_or_store(any, function) :: any
  def get_or_store(key, passed_fn) when is_function(passed_fn) do
    with [] <- :ets.lookup(@table_name, key),
         new_val = passed_fn.(),
         {:ok, :inserted} <- SimpleCache.insert_new(key, new_val) do
      new_val
    else
      [{_key, val, _timer}] -> val
      {:error, _reason} -> get_or_store(key, passed_fn)
    end
  end

  @doc """
  Returns the number of elements in the cache
  """
  @spec size() :: non_neg_integer
  def size() do
    :ets.info(@table_name, :size)
  end

  @doc """
  Sets the ttl to a specific value in ms for an item
  """
  @spec set_ttl_ms(any, pos_integer) ::
          {:ok, :updated} | {:error, :failed_to_update_element}
  def set_ttl_ms(key, time_ms) when time_ms > 0 do
    t_ref = :ets.lookup_element(@table_name, key, 3)
    :timer.cancel(t_ref)
    {:ok, new_t_ref} = :timer.apply_after(time_ms, :ets, :delete, [@table_name, key])

    case :ets.update_element(@table_name, key, {3, new_t_ref}) do
      true ->
        {:ok, :updated}

      false ->
        :timer.cancel(new_t_ref)
        {:error, :failed_to_update_element}
    end
  end
end
