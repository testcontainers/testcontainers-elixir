# SPDX-License-Identifier: MIT
defmodule Testcontainers.Connection.DockerHostStrategy.DockerSocketPath do
  defstruct []

  # Implementing the strategy protocol
  defimpl Testcontainers.Connection.DockerHostStrategy do
    @docker_socket_path "/var/run/docker.sock"

    def execute(_strategy, _input) do
      if File.exists?(@docker_socket_path) do
        # If the socket file exists, return its path with the appropriate prefix.
        {:ok, "unix://" <> @docker_socket_path}
      else
        {:error, :default_docker_socket_not_found}
      end
    end
  end
end
