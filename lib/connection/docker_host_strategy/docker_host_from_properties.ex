defmodule Testcontainers.DockerHostFromPropertiesStrategy do
  @moduledoc false

  @enforce_keys [:key]
  defstruct key: nil, filename: "~/.testcontainers.properties"

  defimpl Testcontainers.DockerHostStrategy do
    alias Testcontainers.DockerUrl
    alias Testcontainers.Util.PropertiesParser

    def execute(strategy, _input) do
      with {:ok, properties} <- PropertiesParser.read_property_file(strategy.filename),
           docker_host <- Map.fetch(properties, strategy.key),
           do: handle_docker_host(docker_host, strategy.key)
    end

    defp handle_docker_host({:ok, docker_host}, key) when is_binary(docker_host) do
      case DockerUrl.test_docker_host(docker_host) do
        :ok ->
          {:ok, docker_host}

        {:error, reason} ->
          {:error, testcontainer_host_from_properties: {reason, key}}
      end
    end

    defp handle_docker_host(:error, key),
      do: {:error, testcontainer_host_from_properties: {:property_not_found, key}}
  end
end
