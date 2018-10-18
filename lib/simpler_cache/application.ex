defmodule SimplerCache.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {SimplerCache.TableWorker, []},
      {SimplerCache.SimpleLock, []}
    ]

    opts = [strategy: :one_for_one, name: SimplerCache.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
