defmodule TokenManager.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TokenManagerWeb.Telemetry,
      TokenManager.Repo,
      {DNSCluster, query: Application.get_env(:token_manager, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TokenManager.PubSub},
      # Start a worker by calling: TokenManager.Worker.start_link(arg)
      # {TokenManager.Worker, arg},
      # Start to serve requests, typically the last entry
      TokenManagerWeb.Endpoint,
    ] ++ token_manager_child(Mix.env())

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TokenManager.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp token_manager_child(:test), do: []
  defp token_manager_child(_env), do: [{TokenManager.Tokens.TokenManager, []}]

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TokenManagerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
