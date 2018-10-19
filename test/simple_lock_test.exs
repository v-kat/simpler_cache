defmodule SimplerLockTest do
  use ExUnit.Case
  use PropCheck

  setup do
    GenServer.call(:cache_lock, :unlock)
    :ok
  end

  property "simple lock failsafe works", numtests: 1 do
    forall {} <- {} do
      :got_lock = GenServer.call(:cache_lock, :request_lock)
      :unable_to_get_lock = GenServer.call(:cache_lock, :request_lock)
      Process.sleep(1000 * 30 + 1)
      equals(:got_lock, GenServer.call(:cache_lock, :request_lock))
    end
  end

  property "simple lock unlock works", numtests: 2 do
    forall {} <- {} do
      :unlocked = GenServer.call(:cache_lock, :unlock)
      :got_lock = GenServer.call(:cache_lock, :request_lock)
      :unlocked = GenServer.call(:cache_lock, :unlock)
      equals(:got_lock, GenServer.call(:cache_lock, :request_lock))
    end
  end

  property "simple lock double unlock is fine", numtests: 2 do
    forall {} <- {} do
      :got_lock = GenServer.call(:cache_lock, :request_lock)
      equals(:unlocked, GenServer.call(:cache_lock, :unlock))
      equals(:unlocked, GenServer.call(:cache_lock, :unlock))
    end
  end
end
