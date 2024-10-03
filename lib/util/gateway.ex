defmodule Testcontainers.GatewayUtil do
  alias Testcontainers.Logger
  alias Testcontainers.Docker.Api

  def get_docker_host(docker_host_url, conn, dockerenv_path \\ "/.dockerenv")

  def get_docker_host(docker_host_url, conn, dockerenv_path) do
    case URI.parse(docker_host_url) do
      uri when uri.scheme == "http" or uri.scheme == "https" ->
        {:ok, uri.host}

      uri when uri.scheme == "http+unix" ->
        if File.exists?(dockerenv_path) do
          Logger.log("Running in docker environment, trying to get bridge network gateway")

          with {:ok, gateway} <- Api.get_bridge_gateway(conn) do
            {:ok, gateway}
          else
            {:error, reason} ->
              Logger.log("Failed to get bridge gateway: #{inspect(reason)}. Using localhost")
              {:ok, "localhost"}
          end
        else
          Logger.log("Not running in docker environment, using localhost")
          {:ok, "localhost"}
        end
    end
  end
end
