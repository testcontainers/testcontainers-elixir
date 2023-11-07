defmodule Hello.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    if Mix.env() == :test do
      {:ok, _container} = Testcontainers.Ecto.postgres_container(app: :hello)

      # to use mysql, change
      # `adapter: Ecto.Adapters.Postgres`
      # in lib/hello/repo.ex, to
      # `adapter: Ecto.Adapters.MyXQL`

      # {:ok, _container} = Testcontainers.Ecto.mysql_container(app: :hello)
    end

    children = [
      HelloWeb.Telemetry,
      Hello.Repo,
      {DNSCluster, query: Application.get_env(:hello, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Hello.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Hello.Finch},
      # Start a worker by calling: Hello.Worker.start_link(arg)
      # {Hello.Worker, arg},
      # Start to serve requests, typically the last entry
      HelloWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Hello.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    HelloWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end