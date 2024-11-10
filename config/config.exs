# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :llama_api,
  ecto_repos: [LlamaApi.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :llama_api, LlamaApiWeb.Endpoint,
  url: [host: "localhost"],
  # secret_key_base: System.get_env("SECRET_KEY_BASE"),
  # adapter: Bandit.PhoenixAdapter,
  render_errors: [view: LlamaApiWeb.ErrorView, accepts: ~w(json)],
  pubsub_server: LlamaApi.PubSub
  # live_view: [signing_salt: "+Qlnp3kp"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.

# Configure esbuild (the version is required)


# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
