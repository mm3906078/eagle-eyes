import Config

if config_env() == :prod do
  master =
    System.get_env("MASTER") ||
      raise """
      MASTER environment variable is not set.
      For example: master@172.55.12.1
      """

  config :vagent, :master, String.to_atom(master)
  config :vcentral, :master, String.to_atom(master)

  cookie =
    System.get_env("COOKIE") ||
      raise """
      COOKIE environment variable is not set.
      For example: secret
      """

  config :vcentral, :cookie, String.to_atom(cookie)
  config :vagent, :cookie, String.to_atom(cookie)
end
