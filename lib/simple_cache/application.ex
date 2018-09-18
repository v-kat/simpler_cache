defmodule SimpleCache.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {SimpleCache.TableWorker, []}
    ]

    opts = [strategy: :one_for_one, name: SimpleCache.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
