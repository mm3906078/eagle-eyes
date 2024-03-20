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
  end
