# SPDX-License-Identifier: MIT
defmodule Testcontainers.DockerHostFromEnvStrategy do
  @moduledoc false

  defstruct key: "DOCKER_HOST"

  alias Testcontainers.DockerUrl

  defimpl Testcontainers.DockerHostStrategy do
    def execute(strategy, _input) do
      with {:ok, docker_host} <- get_docker_host(strategy) do
        case docker_host |> DockerUrl.test_docker_host() do
          :ok ->
            {:ok, docker_host}

          {:error, reason} ->
            {:error, docker_host_from_env: reason}
        end
      end
    end

    defp get_docker_host(strategy) do
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
