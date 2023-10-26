# SPDX-License-Identifier: MIT
defmodule Testcontainers.Connection.DockerHostStrategy.DockerHostFromProperties do
  @enforce_keys [:key]
  defstruct key: nil, filename: "~/.testcontainers.properties"

  defimpl Testcontainers.Connection.DockerHostStrategy do
    alias Testcontainers.DockerUrl

    def execute(strategy, _input) do
      with {:ok, properties} <- read_property_file(expand_path(strategy.filename)),
           docker_host <- Map.fetch(properties, strategy.key),
           do: handle_docker_host(docker_host)
    end

    defp read_property_file(filepath) do
      if File.exists?(filepath) do
        with {:ok, content} <- File.read(filepath),
             properties <- parse_properties(content) do
          {:ok, properties}
        else
          error ->
            {:error, testcontainer_host_from_properties: error}
        end
      else
        {:error, testcontainer_host_from_properties: :file_does_not_exist}
      end
    end

    defp parse_properties(content) do
      content
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
      |> Enum.flat_map(&extract_key_value_pair/1)
      |> Enum.into(%{})
    end

    defp extract_key_value_pair(line) do
      case String.split(line, "=", parts: 2) do
        [key, value] when is_binary(value) ->
          [{String.trim(key), String.trim(value)}]

        _other ->
          []
      end
    end

    defp handle_docker_host({:ok, docker_host}) when is_binary(docker_host) do
      case DockerUrl.test_docker_host(docker_host) do
        :ok ->
          {:ok, docker_host}

        {:error, reason} ->
          {:error, testcontainer_host_from_properties: reason}
      end
    end

    defp handle_docker_host(:error),
      do: {:error, testcontainer_host_from_properties: :property_not_found}

    defp expand_path(path), do: Path.expand(path)
  end
end
