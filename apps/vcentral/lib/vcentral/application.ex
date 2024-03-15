defmodule Vcentral.Application do
  use Application

  def start(_type, _args) do
    children = [
      Vcentral.Master
    ]

    opts = [strategy: :one_for_one, name: Vcentral.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
