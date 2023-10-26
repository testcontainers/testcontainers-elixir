defmodule Testcontainers.DockerUrl do
  @moduledoc false

  @api_version "v1.41"

  @doc false
  def construct(docker_host) do
    case URI.parse(docker_host) do
      %URI{scheme: "unix", path: path} ->
        "http+unix://#{:uri_string.quote(path)}/#{@api_version}"

      %URI{scheme: "tcp"} = uri ->
        URI.to_string(%{uri | scheme: "http", path: "/#{@api_version}"})

      %URI{scheme: _, authority: _} = uri ->
        URI.to_string(%{uri | path: "/#{@api_version}"})
    end
  end

  @doc false
  def test_docker_connection(docker_host_uri) do
    url = "#{construct(docker_host_uri)}/_ping"

    case Tesla.get(url) do
      {:ok, _response} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end
