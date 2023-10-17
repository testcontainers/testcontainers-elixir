# SPDX-License-Identifier: MIT
defmodule Testcontainers.Connection.DockerHostStrategy.RootlessDockerSocketPath do
  defstruct []

  alias Testcontainers.Connection.DockerHostStrategy

  defimpl DockerHostStrategy do
    def execute(_strategy, _input) do
      socket_paths = [
        System.get_env("XDG_RUNTIME_DIR"),
        Path.expand("~/.docker/run/docker.sock"),
        Path.expand("~/.docker/desktop/docker.sock"),
        "/run/user/#{:os.getpid()}/docker.sock"
      ]

      # Check each path and return the first one that exists.
      Enum.reduce_while(socket_paths, {:error, :not_found}, fn path, _acc ->
        if path != nil && File.exists?(path) do
          {:halt, {:ok, "unix://" <> path}}
        else
          {:cont, {:error, :not_found}}
        end
      end)
    end
  end
end
