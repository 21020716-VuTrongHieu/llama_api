defmodule LlamaApi.MixProject do
  use Mix.Project

  def project do
    [
      app: :llama_api,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {LlamaApi.Application, []},
      extra_applications: [:phoenix, :logger, :runtime_tools, :json_web_token, :gettext, :cors_plug, :amqp, :postgrex, :ecto_sql, :ecto, :jason, :telemetry, :telemetry_metrics, :telemetry_poller, :credentials_obfuscation, :nx, :exla, :kino, :bumblebee]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.14"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {:ecto, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:httpoison, "~> 1.0", override: true},
      {:json_web_token, "~> 0.2.10"},
      {:cors_plug, "~> 1.1"},
      {:plug_cowboy, "~> 2.0"},
      {:plug, "~> 1.14"},
      {:amqp, "~> 3.0"},
      {:credentials_obfuscation, "~> 3.4.0"},
      # Các phụ thuộc khác
      # {:phoenix_live_reload, "~> 1.2", only: :dev},
      # TODO bump on release to {:phoenix_live_view, "~> 1.0.0"},
      # {:phoenix_live_view, "~> 1.0.0-rc.1", override: true},
      {:floki, ">= 0.30.0", only: :test},
      # {:phoenix_live_dashboard, "~> 0.8.3"},
      # {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      # {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      # {:heroicons,
      #  github: "tailwindlabs/heroicons",
      #  tag: "v2.1.1",
      #  sparse: "optimized",
      #  app: false,
      #  compile: false,
      #  depth: 1},
      # {:swoosh, "~> 1.5"},
      # {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.2"},
      {:telemetry, "~> 1.2"},
      {:hackney, "~> 1.18"},
      # {:dns_cluster, "~> 0.1.1"},
      # {:bandit, "~> 1.5"},
      {:bumblebee, "~> 0.5.0"},
      {:nx, "~> 0.7.0"},
      {:exla, "~> 0.7.0"},
      {:kino, "~> 0.12.0"},
      {:certifi, "~> 2.6"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
