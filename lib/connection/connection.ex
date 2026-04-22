# SPDX-License-Identifier: MIT
defmodule Testcontainers.Connection do
  @moduledoc false

  require Logger

  alias DockerEngineAPI.Connection
  alias Testcontainers.Constants
  alias Testcontainers.DockerHostFromEnvStrategy
  alias Testcontainers.DockerHostFromPropertiesStrategy
  alias Testcontainers.DockerHostStrategyEvaluator
  alias Testcontainers.DockerSocketPathStrategy
  alias Testcontainers.DockerUrl

  @timeout 300_000

  def get_connection(options \\ []) do
    {docker_host_url, docker_host} =
      get_docker_host_url() |> tap(&Logger.info("Docker host: #{inspect(&1, pretty: false)}"))

    options =
      Keyword.merge(options,
        base_url: docker_host_url,
        recv_timeout: @timeout,
        user_agent: Constants.user_agent()
      )

    options = maybe_add_tls_options(options, docker_host_url)

    {Connection.new(options), docker_host_url, docker_host}
  end

  @doc """
  Builds the list of `:ssl_options` for a TLS-secured Docker daemon.

  Loads `ca.pem`, `cert.pem` and `key.pem` from `DOCKER_CERT_PATH`
  (falling back to `~/.docker`). Missing files are skipped with a debug log.
  When `DOCKER_TLS_VERIFY` is truthy, `verify: :verify_peer` is used; otherwise
  `verify: :verify_none` with a warning log.
  """
  def build_ssl_options do
    cert_dir = cert_dir()

    ssl_options = [verify: verify_mode()]

    ssl_options
    |> maybe_put_file(:cacertfile, Path.join(cert_dir, "ca.pem"))
    |> maybe_put_file(:certfile, Path.join(cert_dir, "cert.pem"))
    |> maybe_put_file(:keyfile, Path.join(cert_dir, "key.pem"))
  end

  defp cert_dir do
    case System.get_env("DOCKER_CERT_PATH") do
      nil -> Path.expand("~/.docker")
      "" -> Path.expand("~/.docker")
      path -> path
    end
  end

  defp verify_mode do
    if DockerUrl.tls_verify?() do
      :verify_peer
    else
      Logger.warning(
        "Docker TLS connection without DOCKER_TLS_VERIFY; peer certificate will NOT be verified"
      )

      :verify_none
    end
  end

  defp maybe_put_file(opts, key, path) do
    if File.exists?(path) do
      Keyword.put(opts, key, path)
    else
      Logger.debug("Docker TLS cert file #{path} not found; skipping #{key}")
      opts
    end
  end

  defp maybe_add_tls_options(options, url) do
    if DockerUrl.https?(url) do
      ssl_options = build_ssl_options()

      adapter_opts = [
        recv_timeout: Keyword.get(options, :recv_timeout, @timeout),
        ssl_options: ssl_options
      ]

      Keyword.put(options, :adapter, {Tesla.Adapter.Hackney, adapter_opts})
    else
      options
    end
  end

  defp get_docker_host_url do
    case get_docker_host() do
      {:ok, docker_host} ->
        {DockerUrl.construct(docker_host), docker_host}

      {:error, error} ->
        exit(error)
    end
  end

  defp get_docker_host do
    strategies = [
      %DockerHostFromPropertiesStrategy{key: "tc.host"},
      %DockerHostFromPropertiesStrategy{key: "docker.host"},
      %DockerHostFromEnvStrategy{},
      %DockerSocketPathStrategy{}
    ]

    DockerHostStrategyEvaluator.run_strategies(strategies, [])
  end
end
