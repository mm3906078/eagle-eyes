defmodule Vcentral.Application do
  use Application

  def start(_type, _args) do
    children = [
      pg_spec(),
      Vcentral.Master,
      # Start the PubSub system
      {Phoenix.PubSub, name: Vcentral.PubSub}
    ]

    opts = [strategy: :one_for_one, name: Vcentral.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp pg_spec do
    %{
      id: :pg,
      start: {:pg, :start_link, []}
    }
  end
end
