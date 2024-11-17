# SPDX-License-Identifier: MIT
defmodule Testcontainers.DockerSocketPathStrategy do
  @moduledoc false

  defstruct socket_paths: []

  defimpl Testcontainers.DockerHostStrategy do
    alias Testcontainers.DockerUrl
    alias Testcontainers.Logger

    defp default_socket_paths do
      [
        Path.expand("~/.docker/run/docker.sock"),
        Path.expand("~/.docker/desktop/docker.sock"),
        "/var/run/docker.sock"
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
      Enum.reduce_while(
        if length(strategy.socket_paths) == 0 do
          default_socket_paths()
        else
          strategy.socket_paths
        end,
        {:error, {:docker_socket_not_found, []}},
        fn path, {:error, {:docker_socket_not_found, tried_paths}} ->
          if path != nil && File.exists?(path) do
            path_with_scheme = "unix://" <> path

            case DockerUrl.test_docker_host(path_with_scheme) do
              :ok ->
                {:halt, {:ok, path_with_scheme}}

              {:error, reason} ->
                Logger.log("Docker socket path #{path} failed: #{reason}")
                {:cont, {:error, {:docker_socket_not_found, tried_paths ++ [path]}}}
            end
          else
            {:cont, {:error, {:docker_socket_not_found, tried_paths ++ [path]}}}
          end
        end
      )
    end
  end
end
