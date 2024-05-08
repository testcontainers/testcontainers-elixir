defmodule Testcontainers.DockerUrl do
  @moduledoc false

  @api_version "v1.41"

  @test_client Tesla.client([], Tesla.Adapter.Hackney)

  def construct(docker_host) do
    case URI.parse(docker_host) do
      %URI{scheme: "unix", path: path} ->
        "http+unix://#{URI.encode_www_form(path)}/#{@api_version}"

      %URI{scheme: "tcp"} = uri ->
        URI.to_string(%{uri | scheme: "http", path: "/#{@api_version}"})

      %URI{scheme: _, authority: _} = uri ->
        URI.to_string(%{uri | path: "/#{@api_version}"})
    end
  end

  def test_docker_host(docker_host) do
    url = "#{construct(docker_host)}/_ping"

    case Tesla.get(@test_client, url) do
      {:ok, _response} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end
