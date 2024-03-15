defmodule Vagent.Application do
  use Application

  def start(_type, _args) do
    children = [
      pg_spec(),
      Vagent.VersionControl,
      Vagent.NodeCtl,
    ]

    opts = [strategy: :one_for_one, name: Vagent.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp pg_spec do
    %{
      id: :pg,
      start: {:pg, :start_link, []}
    }
  end

end
