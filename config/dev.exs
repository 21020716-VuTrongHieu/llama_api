import Config

# Configure your database
# config :llama_api, LlamaApi.Repo,
#   username: "vu_hieu",
#   password: "vu_hieu",
#   hostname: "localhost",
#   database: "llama_api_dev",
#   stacktrace: true,
#   show_sensitive_data_on_connection_error: true,
#   pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we can use it
# to bundle .js and .css sources.
config :llama_api, LlamaApiWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [
    port: 5000,
    # keyfile: "priv/ssl/server_key.pem",
    # certfile: "priv/ssl/server.pem",
  ],
  # http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: false,
  debug_errors: true,
  secret_key_base: "hF1soru2uRUSMMxmwE9di4gNOtAkxtgpdy6n5JjRhRf7ygDrBWJz7jjjq7xQ3zsi",
  watchers: []

# Configure the database
config :llama_api, LlamaApi.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "vu_hieu",
  password: "vu_hieu",
  database: "llama_api_dev",
  hostname: "db",
  pool_size: 10,
  port: 5432

# Enable dev routes for dashboard and mailbox
config :llama_api, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :console,
  level: :debug

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20




