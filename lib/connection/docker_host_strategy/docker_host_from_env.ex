# SPDX-License-Identifier: MIT
defmodule Testcontainers.Connection.DockerHostStrategy.DockerHostFromEnv do
  defstruct key: "DOCKER_HOST"

  defimpl Testcontainers.Connection.DockerHostStrategy do
    def execute(strategy, _input) do
      case System.get_env(strategy.key) do
        nil ->
          {:error, docker_host_from_env: :docker_host_not_found}

        "" ->
          {:error, docker_host_from_env: :docker_host_empty}

        docker_host when is_binary(docker_host) ->
          {:ok, docker_host}
      end
    end
  end
end
