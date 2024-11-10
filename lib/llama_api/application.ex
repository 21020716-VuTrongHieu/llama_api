defmodule LlamaApi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Nx.global_default_backend({EXLA.Backend, client: :host}) # Set the default backend to EXLA
    children = [
      LlamaApi.Repo,
      {LlamaApi.Consumer, []},
      {LlamaApi.LlamaSupervisor, []},
      {Phoenix.PubSub, name: LlamaApi.PubSub},
      LlamaApiWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LlamaApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LlamaApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
