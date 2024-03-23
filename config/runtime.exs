import Config

if config_env() == :prod do
  http_listen_addr =
    System.get_env("HTTP_LISTEN_ADDR") ||
      raise """
      RESTful API listen address.
      environment variable HTTP_LISTEN_ADDR is missing.
      For example: 127.0.0.1
      """

  {:ok, http_listen_ip} = :inet.parse_ipv4strict_address(String.to_charlist(http_listen_addr))

  master =
    System.get_env("MASTER") ||
      raise """
      MASTER environment variable is not set.
      For example: master@172.55.12.1
      """

  config :vagent, :master, String.to_atom(master)

  listen_addr =
    System.get_env("LISTEN_ADDR") ||
      raise """
      AGENT environment variable is not set.
      For example: 172.55.12.1
      """

  config :vagent, :listen_addr, String.to_atom(listen_addr)

  cookie =
    System.get_env("COOKIE") ||
      raise """
      COOKIE environment variable is not set.
      For example: cookie
      """
  config :vagent, :cookie, String.to_atom(cookie)
  config :vcentral, :cookie, String.to_atom(cookie)

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  config :vweb, Vweb.Endpoint,
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      ip: http_listen_ip,
      port: String.to_integer(System.get_env("PORT") || "4000")
    ],
    secret_key_base: secret_key_base

  config :vweb, Vweb.Endpoint, server: true
end
