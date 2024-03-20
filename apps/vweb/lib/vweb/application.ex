defmodule Vweb.Application do
  use Application

  def start(_type, _args) do
    children = [
      Vweb.Endpoint
    ]

    add_syslog_handler()

    opts = [strategy: :one_for_one, name: Vweb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp add_syslog_handler() do
    case :logger.add_handlers(:Vweb) do
      :ok ->
        # remove syslog default handler
        # https://github.com/schlagert/syslog#otp-21-logger-integration
        :logger.remove_handler(:syslog)

      _ ->
        Logger.warn(%{msg: "could not install syslog handler for Vweb"})
    end
  end
end
