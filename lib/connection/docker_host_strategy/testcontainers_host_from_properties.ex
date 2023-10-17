# SPDX-License-Identifier: MIT
defmodule Testcontainers.Connection.DockerHostStrategy.TestcontainersHostFromProperties do
  defstruct []

  defimpl Testcontainers.Connection.DockerHostStrategy do
    @properties_filename "~/.testcontainers.properties"
    @tc_host_key "tc.host"

    def execute(_strategy, _input) do
      with {:ok, properties} <- read_property_file(expand_path(@properties_filename)),
           docker_host <- Map.fetch(properties, @tc_host_key),
           do: handle_docker_host(docker_host)
    end

    defp read_property_file(filepath) do
      if File.exists?(filepath) do
        with {:ok, content} <- File.read(filepath),
             properties <- parse_properties(content),
             do: {:ok, properties}
      else
        {:error, :file_not_found}
      end
    end

    defp parse_properties(content) do
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

    defp handle_docker_host({:ok, docker_host}) when is_binary(docker_host),
      do: {:ok, docker_host}

    defp handle_docker_host(:error), do: {:error, :property_not_found}

    defp expand_path(path), do: Path.expand(path)
  end
end
