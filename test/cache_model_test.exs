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

  property "run the cache", [:verbose] do
    forall cmds <- commands(__MODULE__) do
      trap_exit do
        execution = run_commands(cmds)

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
  # Using streamdata to include map type until propcheck uses proper 1.3 and has a map type

  def key(), do: StreamData.term()

  def val(), do: StreamData.term()

  # This isn't the best because it's not properly deriving a new value from the old value
  # but to do that for all term possibilities would be a bit much
  def update_function(), do: fn old_value -> {old_value, StreamData.term()} end

  def fallback_function(), do: fn -> StreamData.term() end

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
  end

  defcommand :put do
    def impl(key, val), do: SimpleCache.put(key, val)
    def args(_state), do: [key(), val()]
    def next(old_state, [key, val], _call_result), do: Map.put(old_state, key, val)
  end

  defcommand :insert_new do
    def impl(key, val), do: SimpleCache.insert_new(key, val)
    def args(_state), do: [key(), val()]
    def next(old_state, _args, {:error, _any}), do: old_state
    def next(old_state, [key, val], _any), do: Map.put(old_state, key, val)
  end

  defcommand :delete do
    def impl(key), do: SimpleCache.delete(key)
    def args(_state), do: [key()]
    def next(old_state, [key], _call_result), do: Map.delete(old_state, key)
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
  end

  defcommand :get_or_store do
    def impl(key, passed_fn), do: SimpleCache.get_or_store(key, passed_fn)
    def args(_state), do: [key(), fallback_function()]
    def next(old_state, [key, passed_fn], _call_result), do: Map.get(old_state, key, passed_fn.())
  end

  defcommand :size do
    def impl(), do: SimpleCache.size()
    def args(_state), do: []

    # def post(entries, [], call_result) do
    #   IO.inspect(entries)
    #   IO.inspect(call_result)
    #   IO.inspect(:ets.tab2list(:simple_cache))
    #   IO.puts("----------------")
    #   Enum.count(entries) == call_result
    # end
  end
end
