defmodule SimplerCache.TableWorker do
  use GenServer
  @table_name Application.get_env(:simpler_cache, :cache_name, :simpler_cache)

  def start_link(_arg) do
    GenServer.start_link(__MODULE__, %{})
  end

  @impl true
  def init(_state) do
    table =
      :ets.new(@table_name, [
        :set,
        :public,
        :named_table,
        read_concurrency: true,
        write_concurrency: true
      ])

    {:ok, table}
  end
end
