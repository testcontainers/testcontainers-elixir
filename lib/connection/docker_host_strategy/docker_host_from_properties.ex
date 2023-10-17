# SPDX-License-Identifier: MIT
defmodule Testcontainers.Connection.DockerHostStrategy.DockerHostFromProperties do
  defstruct []

  defimpl Testcontainers.Connection.DockerHostStrategy do
    @properties_filename "~/.testcontainers.properties"
    @docker_host_key "docker.host"

    def execute(_strategy, _input) do
      case read_property_file(expand_path(@properties_filename)) do
        {:ok, properties} ->
          extract_docker_host(properties)

        {:error, _} ->
          {:error, :not_found}
      end
    end

    defp read_property_file(filepath) do
      # Read the file if it exists, otherwise return an error.
      if File.exists?(filepath) do
        case File.read(filepath) do
          {:ok, content} ->
            {:ok, parse_properties(content)}

          {:error, reason} ->
            {:error, reason}
        end
      else
        {:error, :file_not_found}
      end
    end

    defp parse_properties(content) do
      # Parse the content of the properties file to extract key-value pairs.
      content
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
      |> Enum.map(fn line ->
        [key, value] = String.split(line, "=", parts: 2)
        {String.trim(key), String.trim(value)}
      end)
      |> Enum.into(%{})
    end

    defp extract_docker_host(properties) do
      # Extract the "docker.host" property if it exists.
      case Map.fetch(properties, @docker_host_key) do
        :error ->
          {:error, :property_not_found}

        {:ok, docker_host} ->
          {:ok, docker_host}
      end
    end

    defp expand_path(path), do: Path.expand(path)
  end
end
