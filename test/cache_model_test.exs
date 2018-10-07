defmodule PropCheck.Test.CacheModel do
  @moduledoc """
  This is a model test with the proper dsl for stateful property testing.
  """
  use ExUnit.Case
  use PropCheck
  use PropCheck.StateM.DSL

  @table_name Application.get_env(:simpler_cache, :cache_name, :simpler_cache)

  #########################################################################
  ### The properties
  #########################################################################

  @tag timeout: 240_000
  property "run the cache commands", [:verbose, numtests: 100, max_size: 60] do
    forall cmds <- commands(__MODULE__) do
      trap_exit do
        execution = run_commands(cmds)
        :ets.delete_all_objects(@table_name)

        (execution.result == :ok)
        |> when_fail(
          IO.puts("""
          History: #{inspect(execution.history, pretty: true)}
          State: #{inspect(execution.state, pretty: true)}
          Env: #{inspect(execution.env, pretty: true)}
          Result: #{inspect(execution.result, pretty: true)}
          """)
        )
        |> aggregate(command_names(cmds))
        |> measure("length of commands", length(cmds))
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

  #########################################################################
  ### The model
  #########################################################################

  def initial_state(), do: %{}

  def weight(_),
    do: %{
      get: 2,
      put: 2,
      insert_new: 2,
      delete: 2,
      update_existing: 1,
      get_or_store: 3,
      size: 1
    }

  defcommand :get do
    def impl(key), do: SimplerCache.get(key)
    def args(_state), do: [key()]

    def post(entries, [key], call_result) do
      call_result == Map.get(entries, key)
    end
  end

  defcommand :put do
    def impl(key, val), do: SimplerCache.put(key, val)
    def args(_state), do: [key(), val()]
    def next(old_state, _args, {:error, _any}), do: old_state
    def next(old_state, [key, val], _any), do: Map.put(old_state, key, val)

    def post(entries, [key, _val], call_result) do
      case Map.get(entries, key) do
        _any ->
          call_result == {:ok, :inserted}
      end
    end
  end

  defcommand :insert_new do
    def impl(key, val), do: SimplerCache.insert_new(key, val)
    def args(_state), do: [key(), val()]
    def next(old_state, _args, {:error, _any}), do: old_state
    def next(old_state, [key, val], _any), do: Map.put_new(old_state, key, val)

    def post(entries, [key, _new_val], call_result) do
      case Map.has_key?(entries, key) do
        true ->
          call_result == {:error, :item_is_in_cache}

        false ->
          call_result == {:ok, :inserted}
      end
    end
  end

  defcommand :delete do
    def impl(key), do: SimplerCache.delete(key)
    def args(_state), do: [key()]

    def next(old_state, [key], _call_result), do: Map.delete(old_state, key)

    def post(entries, [key], call_result) do
      case Map.get(entries, key) do
        nil ->
          call_result == {:ok, :not_found}

        _any ->
          call_result == {:ok, :deleted}
      end
    end
  end

  defcommand :update_existing do
    def impl(key, passed_fn), do: SimplerCache.update_existing(key, passed_fn)
    def args(_state), do: [key(), update_function()]

    def next(old_state, [key, update_fn], _call_result) do
      case Map.get(old_state, key) do
        nil ->
          old_state

        _ ->
          Map.update!(old_state, key, update_fn)
      end
    end

    def post(entries, [key, _fn], call_result) do
      case Map.get(entries, key) do
        nil -> call_result == {:error, :failed_to_find_entry}
        _ -> call_result == {:ok, :updated}
      end
    end
  end

  defcommand :get_or_store do
    def impl(key, fallback_fn), do: SimplerCache.get_or_store(key, fallback_fn)
    def args(_state), do: [key(), fallback_function()]

    def next(old_state, [key, fallback_fn], _call_result) do
      case Map.get(old_state, key) do
        nil ->
          Map.put(old_state, key, fallback_fn.())

        _val ->
          old_state
      end
    end

    def post(entries, [key, fallback_fn], call_result) do
      call_result == Map.get(entries, key, fallback_fn.())
    end
  end

  defcommand :size do
    def impl(), do: SimplerCache.size()
    def args(_state), do: []

    def post(entries, [], call_result) do
      Enum.count(entries) == call_result
    end
  end
end
