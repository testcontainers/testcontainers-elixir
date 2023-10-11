# SPDX-License-Identifier: Apache-2.0
defmodule TestcontainersElixir do
  @moduledoc """
  Documentation for `TestcontainersElixir`.
  """

  def hello do
    DockerEngineAPI.Connection.new(
      base_url: base_url()
    )
    |> DockerEngineAPI.Api.Image.image_list()
  end

  @socket_path "unix:///var/run/docker.sock"
  @default_version "v1.43"

  defp base_url() do
    host = Application.get_env(:docker, :host) || System.get_env("DOCKER_HOST", @socket_path)
    version =
      case Application.get_env(:docker, :version) do
        nil -> @default_version
        version -> version
      end


    "#{normalize_host(host)}/#{version}"
    |> String.trim_trailing("/")
  end

  defp normalize_host("tcp://" <> host), do: "http://" <> host
  defp normalize_host("unix://" <> host), do: "http+unix://" <> URI.encode_www_form(host)

end
