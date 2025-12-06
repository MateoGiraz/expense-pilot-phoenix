# Derive Jason.Encoder for Decimal to allow JSON encoding
require Protocol
# Protocol.derive(Jason.Encoder, Decimal)

defmodule ExpensePilot.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Load environment variables from .env file in all environments
    Dotenv.load()

    children = [
      ExpensePilotWeb.Telemetry,
      ExpensePilot.Repo,
      {DNSCluster, query: Application.get_env(:expense_pilot, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ExpensePilot.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: ExpensePilot.Finch},
      # Note: Email Worker removed - now handled by the notification service
      # Start to serve requests, typically the last entry
      ExpensePilotWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ExpensePilot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ExpensePilotWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
