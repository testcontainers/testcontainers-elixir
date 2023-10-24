# SPDX-License-Identifier: MIT
defmodule Testcontainers.Connection do
  alias Testcontainers.Logger
  alias Testcontainers.Connection.DockerHostStrategyEvaluator
  alias Testcontainers.Connection.DockerHostStrategy.DockerSocketPath
  alias Testcontainers.Connection.DockerHostStrategy.DockerHostFromProperties
  alias Testcontainers.Connection.DockerHostStrategy.DockerHostFromEnv
  alias Testcontainers.Connection.DockerHostStrategy.DockerHostFromProperties
  alias DockerEngineAPI.Connection

  @api_version "v1.41"
  @timeout 300_000

  def get_connection(options \\ []) do
    docker_host_url = docker_base_url()

    Logger.log("Using docker host url: #{docker_host_url}")

    options = Keyword.merge(options, base_url: docker_host_url, recv_timeout: @timeout)

    Connection.new(options)
  end

  defp docker_base_url do
    strategies = [
      %DockerHostFromProperties{key: "tc.host"},
      %DockerHostFromEnv{},
      %DockerSocketPath{socket_paths: ["/var/run/docker.sock"]},
      %DockerHostFromProperties{key: "docker.host"},
      %DockerSocketPath{}
    ]

    case DockerHostStrategyEvaluator.run_strategies(strategies, []) do
      {:ok, "unix://" <> path} ->
        "http+unix://#{:uri_string.quote(path)}/#{@api_version}"

      {:ok, docker_host} ->
        construct_url_from_docker_host(docker_host)

      :error ->
        exit("Failed to find docker host")
    end
  end

  defp construct_url_from_docker_host(docker_host) do
    uri = URI.parse(docker_host)

    case uri do
      %URI{scheme: "tcp"} ->
        URI.to_string(%{uri | scheme: "http", path: "/#{@api_version}"})

      %URI{scheme: _, authority: _} = uri ->
        URI.to_string(%{uri | path: "/#{@api_version}"})
    end
  end
end
