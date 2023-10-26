# SPDX-License-Identifier: MIT
defmodule Testcontainers.Connection.DockerHostStrategy.DockerSocketPath do
  @rootless_docker_socket_paths [
    System.get_env("XDG_RUNTIME_DIR"),
    Path.expand("~/.docker/run/docker.sock"),
    Path.expand("~/.docker/desktop/docker.sock"),
    "/run/user/#{:os.getpid()}/docker.sock"
  ]

  defstruct socket_paths: @rootless_docker_socket_paths

  alias Testcontainers.Connection.DockerHostStrategy

  defimpl DockerHostStrategy do
    alias Testcontainers.DockerUrl

    def execute(strategy, _input) do
      Enum.reduce_while(
        strategy.socket_paths,
        {:error, docker_socket_path: :docker_socket_not_found},
        fn path, _acc ->
          if path != nil && File.exists?(path) do
            path_with_scheme = "unix://" <> path

            case DockerUrl.test_docker_host(path_with_scheme) do
              :ok ->
                {:halt, {:ok, path_with_scheme}}

              {:error, reason} ->
                {:cont, {:error, docker_socket_path: reason}}
            end
          else
            {:cont, {:error, docker_socket_path: :docker_socket_not_found}}
          end
        end
      )
    end
  end
end
