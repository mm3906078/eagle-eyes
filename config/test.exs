import Config

# Configure test environment
config :logger, level: :warning

# Disable master connection for tests
config :vagent, :master, nil
config :vagent, :demo, true

# Test-specific configurations
config :vweb, Vweb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_for_testing_only_not_for_production",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Disable telegram notifications in tests
config :vcentral, :telegram_bot_token, nil
config :vcentral, :telegram_chat_id, nil

# Disable applications that might conflict during testing
config :vcentral, start_applications: false
config :vweb, start_applications: false

# Disable VersionControl automatic startup in tests
config :vagent, :disable_version_control, true
