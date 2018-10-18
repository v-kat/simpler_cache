defmodule SimplerCache.SimpleLock do
  use GenServer

  def start_link(_arg) do
    GenServer.start_link(__MODULE__, %{}, name: :cache_lock)
  end

  @impl true
  def init(_state) do
    {:ok, :unlocked}
  end

  @impl true
  def handle_call(:request_lock, _from, :unlocked) do
    # In 20 seconds unlock failsafe
    Process.send_after(self(), :unlock, 1000 * 20)
    {:reply, :got_lock, :locked}
  end

  @impl true
  def handle_call(:request_lock, _from, :locked) do
    {:reply, :unable_to_get_lock, :locked}
  end

  @impl true
  def handle_call(:unlock, _from, _any) do
    {:reply, :unlocked, :unlocked}
  end
end
