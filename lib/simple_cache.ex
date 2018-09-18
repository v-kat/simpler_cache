defmodule SimpleCache do
  @table_name Application.get_env(:simple_cache, :cache_name, :simple_cache)
  @global_ttl_ms Application.get_env(:simple_cache, :global_ttl_ms, 10_000)
  @moduledoc """
  Documentation for SimpleCache.
  """

  @doc """

  """
  def get(key) do
    :ets.lookup(@table_name, key) |> List.first()
  end

  @doc """
  Inserts value or overwrites it
  """
  def put(key, value) do
    {:ok, t_ref} = :timer.apply_after(@global_ttl_ms, :ets, :delete, [@table_name, key])
    :ets.insert(@table_name, {key, value, t_ref})
  end

  @doc """
  Inserts new value into cache
  """
  def insert_new(key, value) do
    {:ok, t_ref} = :timer.apply_after(@global_ttl_ms, :ets, :delete, [@table_name, key])
    :ets.insert_new(@table_name, {key, value, t_ref})
  end

  @doc """
  Deletes value from cache
  """
  def delete(key) do
    t_ref = :ets.lookup_element(@table_name, key, 3)
    :timer.cancel(t_ref)
    :ets.delete(@table_name, key)
  end

  @doc """
  Updates existing value in cache based on old value.
  Warning the below may thrash a bit on heavy contention.
  """
  # def update_existing(key, fn(old_value) -> ... end) do
  def update_existing(key, passed_fn) do
    with [{key, old_val, _timer}] <- :ets.take(@table_name, key),
         true <- SimpleCache.insert_new(key, passed_fn.(old_val)) do
      true
    else
      [] ->
        false

      _ ->
        get_or_store(key, passed_fn)
    end
  end

  @doc """
  Gets or stores a value based on a passed in function.
  Warning the below may thrash a bit on heavy contention.
  """
  defp get_or_store(key, passed_fn) do
    case :ets.take(@table_name, key) do
      [] ->
        new_val = passed_fn.()

        case SimpleCache.insert_new(key, new_val) do
          false ->
            get_or_store(key, passed_fn)

          true ->
            new_val
        end

      [{key, val, _timer}] ->
        val
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
  Sets the ttl to a specific value in ms
  """
  def set_ttl_ms(key, time_ms) do
    t_ref = :ets.lookup_element(@table_name, key, 3)
    :timer.cancel(t_ref)
    {:ok, t_ref} = :timer.apply_after(time_ms, :ets, :delete, [@table_name, key])
    :ets.update_element(@table_name, key, {3, t_ref})
  end
end
