# SPDX-License-Identifier: MIT
defmodule Testcontainers.Connection do
  @moduledoc false

  require Logger

  alias DockerEngineAPI.Connection
  alias Testcontainers.Constants
  alias Testcontainers.DockerHostFromEnvStrategy
  alias Testcontainers.DockerHostFromPropertiesStrategy
  alias Testcontainers.DockerHostStrategyEvaluator
  alias Testcontainers.DockerSocketPathStrategy
  alias Testcontainers.DockerUrl

  @timeout 300_000

  def get_connection(options \\ []) do
    {docker_host_url, docker_host} =
      get_docker_host_url() |> tap(&Logger.info("Docker host: #{inspect(&1, pretty: false)}"))

    options =
      Keyword.merge(options,
        base_url: docker_host_url,
        recv_timeout: @timeout,
        user_agent: Constants.user_agent()
      )

    {Connection.new(options), docker_host_url, docker_host}
  end

  defp get_docker_host_url do
    case get_docker_host() do
      {:ok, docker_host} ->
        {DockerUrl.construct(docker_host), docker_host}

      {:error, error} ->
        exit(error)
    end
  end

  defp get_docker_host do
    strategies = [
      %DockerHostFromPropertiesStrategy{key: "tc.host"},
      %DockerHostFromPropertiesStrategy{key: "docker.host"},
      %DockerHostFromEnvStrategy{},
      %DockerSocketPathStrategy{}
    ]

    DockerHostStrategyEvaluator.run_strategies(strategies, [])
  end
end
