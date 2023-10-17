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
    def execute(strategy, _input) do
      Enum.reduce_while(
        strategy.socket_paths,
        {:error, docker_socket_path: :docker_socket_not_found},
        fn path, _acc ->
          if path != nil && File.exists?(path) do
            {:halt, {:ok, "unix://" <> path}}
          else
            {:cont, {:error, docker_socket_path: :docker_socket_not_found}}
          end
        end
      )
    end
  end
end
