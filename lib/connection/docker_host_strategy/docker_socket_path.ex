# SPDX-License-Identifier: MIT
defmodule Testcontainers.DockerSocketPathStrategy do
  @moduledoc false

  require Logger

  defstruct socket_paths: []

  defimpl Testcontainers.DockerHostStrategy do
    alias Testcontainers.DockerUrl

    defp default_socket_paths do
      [
        "/var/run/docker.sock",
        Path.expand("~/.docker/run/docker.sock"),
        Path.expand("~/.docker/desktop/docker.sock")
      ] ++
        case System.get_env("XDG_RUNTIME_DIR") do
          nil ->
            []

          path ->
            [
              "#{path}/podman/podman.sock",
              "#{path}/docker.sock"
            ]
        end
    end

    def execute(strategy, _input) do
      paths =
        case strategy.socket_paths do
          [] -> default_socket_paths()
          paths -> paths
        end

      Enum.reduce_while(paths, {:error, {:docker_socket_not_found, []}}, &try_socket_path/2)
    end

    defp try_socket_path(path, {:error, {:docker_socket_not_found, tried_paths}}) do
      if path != nil && File.exists?(path) do
        probe_socket(path, tried_paths)
      else
        {:cont, {:error, {:docker_socket_not_found, tried_paths ++ [path]}}}
      end
    end

    defp probe_socket(path, tried_paths) do
      path_with_scheme = "unix://" <> path

      case DockerUrl.test_docker_host(path_with_scheme) do
        :ok ->
          {:halt, {:ok, path_with_scheme}}

        {:error, reason} ->
          Logger.debug("Docker socket path #{path} failed: #{reason}")
          {:cont, {:error, {:docker_socket_not_found, tried_paths ++ [path]}}}
      end
    end
  end
end
