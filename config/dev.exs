import Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we can use it
# to bundle .js and .css sources.
config :vweb, Vweb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  allowed_cors_profile: "all",
  watchers: [],
  secret_key_base: "w7S7NjZZQhGXO/kyx++RDwbvKhIICUmgu85vHFpcW5JdE+yP51qZ5sYqmhn0fJ4R"

config :vweb, Vweb.Endpoint, server: true

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :logger, level: :debug

config :vagent, :master, :"vcentral@192.168.1.10"
config :vcentral, :master, :"vcentral@192.168.1.10"

config :vagent, :demo, true
