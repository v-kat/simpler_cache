defmodule PropCheck.Test.CacheStateM do
  @moduledoc """
  This is a model test with the proper statem for stateful parallel property testing.
  """
  use ExUnit.Case
  use PropCheck
  use PropCheck.StateM

  @table_name Application.get_env(:simpler_cache, :cache_name, :simpler_cache)

  #########################################################################
  ### The properties
  #########################################################################

  @tag timeout: 240_000
  property "run the cache commands in parallel", [:verbose, numtests: 300, max_size: 40] do
    forall cmds in parallel_commands(__MODULE__) do
      trap_exit do
        :ets.delete_all_objects(@table_name)
        {history, state, result} = run_parallel_commands(__MODULE__, cmds)
        :ets.delete_all_objects(@table_name)

        # (result == :ok || result == :no_possible_interleaving)
        (result == :ok)
        |> when_fail(
          IO.puts("""
          History: #{inspect(history, pretty: true)}
          State: #{inspect(state, pretty: true)}
          Result: #{inspect(result, pretty: true)}
          """)
        )
        |> aggregate(command_names(cmds))
      end
    end
  end

  #########################################################################
  ### Generators
  #########################################################################

  defp key(), do: term()

  defp val(), do: term()

  defp update_function(), do: function(1, term())

  defp fallback_function(), do: function(0, term())

  def command(_state) do
    frequency([
      {2, {:call, SimplerCache, :get, [key()]}},
      {2, {:call, SimplerCache, :put, [key(), val()]}},
      {2, {:call, SimplerCache, :insert_new, [key(), val()]}},
      {2, {:call, SimplerCache, :delete, [key()]}},
      {1, {:call, SimplerCache, :update_existing, [key(), update_function()]}},
      {3, {:call, SimplerCache, :get_or_store, [key(), fallback_function()]}}
    ])
  end

  #########################################################################
  ### The model
  #########################################################################

  def initial_state(), do: %{}

  def next_state(old_state, _any, {:call, SimplerCache, :get, [_args]}), do: old_state

  def next_state(old_state, _any, {:call, SimplerCache, :put, [_args]}), do: old_state

  def next_state(old_state, {:error, _any}, {:call, SimplerCache, :put, [_args]}), do: old_state

  def next_state(old_state, _any, {:call, SimplerCache, :put, [key, val]}),
    do: Map.put(old_state, key, val)

  def next_state(old_state, {:error, _any}, {:call, SimplerCache, :insert_new, [_args]}),
    do: old_state

  def next_state(old_state, _any, {:call, SimplerCache, :insert_new, [key, val]}),
    do: Map.put_new(old_state, key, val)

  def next_state(old_state, _any, {:call, SimplerCache, :insert_new, [_args]}),
    do: old_state

  def next_state(old_state, _any, {:call, SimplerCache, :delete, [key]}),
    do: Map.delete(old_state, key)

  def next_state(old_state, _any, {:call, SimplerCache, :update_existing, [key, update_fn]}) do
    case Map.get(old_state, key) do
      nil ->
        old_state

      _ ->
        Map.update!(old_state, key, update_fn)
    end
  end

  def next_state(old_state, _any, {:call, SimplerCache, :get_or_store, [key, fallback_fn]}) do
    case Map.get(old_state, key) do
      nil ->
        Map.put(old_state, key, fallback_fn.())

      _val ->
        old_state
    end
  end

  def precondition(_state, _call), do: true

  def postcondition(entries, {:call, SimplerCache, :get, [key]}, call_result),
    do: call_result == Map.get(entries, key)

  def postcondition(entries, {:call, SimplerCache, :put, [key, _val]}, call_result) do
    case Map.get(entries, key) do
      _any ->
        call_result == {:ok, :inserted}
    end
  end

  def postcondition(entries, {:call, SimplerCache, :insert_new, [key, _new_val]}, call_result) do
    case Map.has_key?(entries, key) do
      true ->
        call_result == {:error, :item_is_in_cache}

      false ->
        call_result == {:ok, :inserted}
    end
  end

  def postcondition(entries, {:call, SimplerCache, :delete, [key]}, call_result) do
    case Map.get(entries, key) do
      nil ->
        call_result == {:ok, :not_found}

      _any ->
        call_result == {:ok, :deleted}
    end
  end

  def postcondition(entries, {:call, SimplerCache, :update_existing, [key, _fn]}, call_result) do
    case Map.get(entries, key) do
      nil -> call_result == {:error, :failed_to_find_entry}
      _ -> call_result == {:ok, :updated}
    end
  end

  def postcondition(
        entries,
        {:call, SimplerCache, :get_or_store, [key, fallback_fn]},
        call_result
      ),
      do: call_result == Map.get(entries, key, fallback_fn.())
end
