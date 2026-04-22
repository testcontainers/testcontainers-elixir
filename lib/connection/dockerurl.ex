defmodule Testcontainers.DockerUrl do
  @moduledoc false

  @test_client Tesla.client([], Tesla.Adapter.Hackney)

  def construct(docker_host) do
    case URI.parse(docker_host) do
      %URI{scheme: "unix", path: path} ->
        "http+unix://#{URI.encode_www_form(path)}"

      %URI{scheme: "tcp"} = uri ->
        if tls_verify?() do
          URI.to_string(%{uri | scheme: "https"})
        else
          URI.to_string(%{uri | scheme: "http"})
        end

      %URI{scheme: "https"} = uri ->
        URI.to_string(uri)

      %URI{scheme: "http"} = uri ->
        URI.to_string(uri)

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

  @doc """
  Returns true if `DOCKER_TLS_VERIFY` is set to a truthy value (`"1"` or `"true"`).
  """
  def tls_verify? do
    case System.get_env("DOCKER_TLS_VERIFY") do
      "1" -> true
      "true" -> true
      _ -> false
    end
  end

  @doc """
  Returns true if the URL uses the `https` scheme.
  """
  def https?(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: "https"} -> true
      _ -> false
    end
  end

  def https?(_), do: false
end
