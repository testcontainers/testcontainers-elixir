defmodule Testcontainers.Util.PropertiesParser do
  @moduledoc false

  @file_path "~/.testcontainers.properties"

  def read_property_file(file_path \\ @file_path) do
    if File.exists?(Path.expand(file_path)) do
      with {:ok, content} <- File.read(Path.expand(file_path)),
           properties <- parse_properties(content) do
        {:ok, properties}
      else
        error ->
          {:error, properties: error}
      end
    else
      # return empty map if file does not exist
      {:ok, %{}}
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
end
