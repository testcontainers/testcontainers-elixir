# SPDX-License-Identifier: MIT
defmodule Testcontainers.DockerSocketPathStrategy do
  @moduledoc false

  @docker_socket_paths [
    Path.expand("~/.docker/run/docker.sock"),
    Path.expand("~/.docker/desktop/docker.sock"),
    "/run/user/#{:os.getpid()}/podman/podman.sock",
    "/run/user/#{:os.getpid()}/docker.sock",
    "/var/run/docker.sock"
  ]

  defstruct socket_paths: @docker_socket_paths

  defimpl Testcontainers.DockerHostStrategy do
    alias Testcontainers.DockerUrl
    alias Testcontainers.Logger

    def execute(strategy, _input) do
      Enum.reduce_while(
        strategy.socket_paths,
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
