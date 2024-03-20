import Config

config :vweb, Vweb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: Vweb.ErrorView, accepts: ~w(json html), layout: false],
  pubsub_server: Vcentral.PubSub

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :mfa, :file, :line]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
