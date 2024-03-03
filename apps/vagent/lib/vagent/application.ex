defmodule Vagent.Application do
  use Application

  def start(_type, _args) do
    children = [
      Vagent.VersionControl
    ]

    opts = [strategy: :one_for_one, name: Vagent.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
