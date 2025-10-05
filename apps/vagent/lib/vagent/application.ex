defmodule Vagent.Application do
  use Application

  def start(_type, _args) do
    children =
      [
        maybe_pg_spec(),
        maybe_version_control_spec(),
        Vagent.NodeCtl
      ]
      |> Enum.reject(&is_nil/1)

    opts = [strategy: :one_for_one, name: Vagent.Supervisor]
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

  defp maybe_version_control_spec do
    if Application.get_env(:vagent, :disable_version_control, false) do
      # Skip VersionControl in tests
      nil
    else
      Vagent.VersionControl
    end
  end
end
