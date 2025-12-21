defmodule Testcontainers.DockerUrl do
  @moduledoc false

  @test_client Tesla.client([], Tesla.Adapter.Hackney)

  def construct(docker_host) do
    case URI.parse(docker_host) do
      %URI{scheme: "unix", path: path} ->
        "http+unix://#{URI.encode_www_form(path)}"

      %URI{scheme: "tcp"} = uri ->
        URI.to_string(%{uri | scheme: "http"})

      %URI{scheme: _, authority: _} = uri ->
        uri
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
