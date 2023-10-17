# SPDX-License-Identifier: MIT
defmodule Testcontainers.Connection.DockerHostStrategy.DockerHostFromEnv do
  defstruct []

  defimpl Testcontainers.Connection.DockerHostStrategy do
    def execute(_strategy, _input) do
      case System.get_env("DOCKER_HOST") do
        nil ->
          {:error, :docker_host_not_found}

        "" ->
          {:error, :docker_host_empty}

        docker_host when is_binary(docker_host) ->
          {:ok, docker_host}
      end
    end
  end
end
