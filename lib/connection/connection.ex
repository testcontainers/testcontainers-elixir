# SPDX-License-Identifier: MIT
defmodule Testcontainers.Connection do
  @moduledoc false

  require Logger

  alias Testcontainers.Constants
  alias Testcontainers.DockerUrl
  alias Testcontainers.DockerHostStrategyEvaluator
  alias Testcontainers.DockerSocketPathStrategy
  alias Testcontainers.DockerHostFromPropertiesStrategy
  alias Testcontainers.DockerHostFromEnvStrategy
  alias DockerEngineAPI.Connection

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
    with {:ok, docker_host} <- get_docker_host() do
      {DockerUrl.construct(docker_host), docker_host}
    else
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
