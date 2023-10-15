# SPDX-License-Identifier: MIT
defmodule Testcontainers.Docker.Connection do
  alias DockerEngineAPI.Connection

  @default_host "unix:///var/run/docker.sock"
  @api_version "v1.41"
  @timeout 60_000

  def get_connection(options \\ []) do
    options = Keyword.merge(options, base_url: docker_base_url(), recv_timeout: @timeout)
    Connection.new(options)
  end

  defp docker_base_url do
    case System.get_env("DOCKER_HOST", @default_host) do
      "unix://" <> host -> "http+unix://" <> :uri_string.quote(host) <> "/" <> @api_version
      "tcp://" <> host -> "http://" <> :uri_string.quote(host) <> "/" <> @api_version
    end
  end
end
