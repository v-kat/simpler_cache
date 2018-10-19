defmodule SimplerCache.SimpleLock do
  use GenServer

  def start_link(_arg) do
    GenServer.start_link(__MODULE__, %{}, name: :cache_lock)
  end

  @impl true
  def init(_state) do
    {:ok, {:unlocked, nil}}
  end

  @impl true
  def handle_call(:request_lock, _from, {:unlocked, nil}) do
    # In 30 seconds unlock failsafe
    timer_ref = Process.send_after(self(), :unlock, 1000 * 30)
    {:reply, :got_lock, {:locked, timer_ref}}
  end

  @impl true
  def handle_call(:request_lock, _from, {:locked, _maybe_timer_ref} = old_state) do
    {:reply, :unable_to_get_lock, old_state}
  end

  @impl true
  def handle_call(:unlock, _from, {_any, nil}) do
    {:reply, :unlocked, {:unlocked, nil}}
  end

  @impl true
  def handle_call(:unlock, _from, {_any, timer_ref}) do
    Process.cancel_timer(timer_ref)
    {:reply, :unlocked, {:unlocked, nil}}
  end

  @impl true
  def handle_info(:unlock, _any) do
    {:noreply, {:unlocked, nil}}
  end
end
