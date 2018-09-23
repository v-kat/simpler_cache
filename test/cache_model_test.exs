defmodule PropCheck.Test.CacheModel do
  @moduledoc """
  This is a model test with the proper dsl for stateful property testing.
  """
  use ExUnit.Case
  use PropCheck
  use PropCheck.StateM.DSL
  require Logger

  #########################################################################
  ### The properties
  #########################################################################

  @tag timeout: 240_000
  property "run the cache", [:verbose] do
    forall cmds <- commands(__MODULE__) do
      trap_exit do
        execution = run_commands(cmds)
        :ets.delete_all_objects(:simple_cache)

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

  # Generators for keys and values
  # terms -> integer for testing purposes
  def key(), do: integer()

  def val(), do: integer()

  # This isn't the best because it's not properly deriving a new value from the old value
  # but to do that for all integer possibilities would be a bit much
  def update_function(), do: fn old_value -> {old_value, integer()} end

  def fallback_function(), do: fn -> integer() end

  #########################################################################
  ### The model
  #########################################################################

  def initial_state(), do: %{}

  def weight(_),
    do: %{
      get: 1,
      put: 2,
      insert_new: 1,
      delete: 1,
      update_existing: 1,
      get_or_store: 2,
      size: 1
    }

  defcommand :get do
    def impl(key), do: SimpleCache.get(key)
    def args(_state), do: [key()]

    def post(entries, [key], call_result) do
      call_result == Map.get(entries, key)
    end
  end

  defcommand :put do
    def impl(key, val), do: SimpleCache.put(key, val)
    def args(_state), do: [key(), val()]
    def next(old_state, [key, val], _call_result), do: Map.put(old_state, key, val)

    def post(entries, [key, _val], call_result) do
      case Map.get(entries, key) do
        _res -> call_result == {:ok, :inserted}
      end
    end
  end

  defcommand :insert_new do
    def impl(key, val), do: SimpleCache.insert_new(key, val)
    def args(_state), do: [key(), val()]
    def next(old_state, _args, {:error, _any}), do: old_state
    def next(old_state, [key, val], _any), do: Map.put(old_state, key, val)

    # def post(entries, [key, new_val], call_result) do
    #   case Map.get(entries, key) do
    #     val when val == new_val -> call_result == {:error, :item_is_in_cache}
    #     _any -> call_result == {:ok, :inserted}
    #   end
    # end
  end

  defcommand :delete do
    def impl(key), do: SimpleCache.delete(key)
    def args(_state), do: [key()]
    def next(old_state, [key], _call_result), do: Map.delete(old_state, key)

    # def post(entries, [key], call_result) do
    #   case Map.get(entries, key) do
    #     nil ->
    #       call_result == true

    #     _any ->
    #       IO.inspect("wtf----------")
    #       IO.inspect(entries)
    #       call_result == false
    #   end
    # end
  end

  defcommand :update_existing do
    def impl(key, passed_fn), do: SimpleCache.update_existing(key, passed_fn)
    def args(_state), do: [key(), update_function()]

    def next(old_state, [key, passed_fn], _call_result) do
      case Map.get_and_update(old_state, key, passed_fn) do
        {nil, _new_state} -> old_state
        {_any, new_state} -> new_state
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
    def impl(key, fallback_fn), do: SimpleCache.get_or_store(key, fallback_fn)
    def args(_state), do: [key(), fallback_function()]

    def next(old_state, [key, fallback_fn], _call_result) do
      case Map.get(old_state, key) do
        nil ->
          Map.put(old_state, key, fallback_fn.())

        _val ->
          old_state
      end
    end

    # def post(entries, [key, _fallback_fn], call_result) do
    #   call_result == Map.get(entries, key)
    # end
  end

  defcommand :size do
    def impl(), do: SimpleCache.size()
    def args(_state), do: []

    def post(entries, [], call_result) do
      Enum.count(entries) == call_result
    end
  end
end
