# SPDX-License-Identifier: MIT
defmodule Testcontainers.Connection do
  @moduledoc false

  alias Testcontainers.DockerUrl
  alias Testcontainers.Logger
  alias Testcontainers.DockerHostStrategyEvaluator
  alias Testcontainers.DockerSocketPathStrategy
  alias Testcontainers.DockerHostFromPropertiesStrategy
  alias Testcontainers.DockerHostFromEnvStrategy
  alias DockerEngineAPI.Connection

  @timeout 300_000

  def get_connection(options \\ []) do
    docker_host_url = docker_base_url()

    Logger.log("Using docker host url: #{docker_host_url}")

    options = Keyword.merge(options, base_url: docker_host_url, recv_timeout: @timeout)

    {Connection.new(options), docker_host_url}
  end

  defp docker_base_url do
    strategies = [
      %DockerHostFromPropertiesStrategy{key: "tc.host"},
      %DockerHostFromEnvStrategy{},
      %DockerSocketPathStrategy{socket_paths: ["/var/run/docker.sock"]},
      %DockerHostFromPropertiesStrategy{key: "docker.host"},
      %DockerSocketPathStrategy{}
    ]

    case DockerHostStrategyEvaluator.run_strategies(strategies, []) do
      {:ok, docker_host} ->
        DockerUrl.construct(docker_host)

      :error ->
        exit("Failed to find docker host")
    end
  end
end
