defmodule Vcentral.Application do
  use Application

  def start(_type, _args) do
    children =
      [
        maybe_pg_spec(),
        Vcentral.Master,
        # Start the PubSub system
        {Phoenix.PubSub, name: Vcentral.PubSub}
      ]
      |> Enum.reject(&is_nil/1)

    opts = [strategy: :one_for_one, name: Vcentral.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp maybe_pg_spec do
    if Process.whereis(:pg) do
      # :pg already started
      nil
    else
      %{
        id: :pg,
        start: {:pg, :start_link, []}
      }
    end
  end
end
