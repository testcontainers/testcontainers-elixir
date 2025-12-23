defmodule Testcontainers.Util.PropertiesParser do
  @moduledoc false

  @user_file "~/.testcontainers.properties"
  @project_file ".testcontainers.properties"
  @env_prefix "TESTCONTAINERS_"

  def read_property_file(file_path \\ @user_file) do
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

  @doc """
  Reads properties from all sources with proper precedence.

  Configuration is read from three sources with the following precedence
  (highest to lowest):

  1. Environment variables (TESTCONTAINERS_* prefix)
  2. User file (~/.testcontainers.properties)
  3. Project file (.testcontainers.properties)

  Environment variables are converted from TESTCONTAINERS_PROPERTY_NAME format
  to property.name format (uppercase to lowercase, underscores to dots, prefix removed).

  ## Options

  - `:user_file` - path to user properties file (default: ~/.testcontainers.properties)
  - `:project_file` - path to project properties file (default: .testcontainers.properties)
  - `:env_prefix` - environment variable prefix (default: TESTCONTAINERS_)

  Returns `{:ok, map}` with merged properties.
  """
  def read_property_sources(opts \\ []) do
    user_file = Keyword.get(opts, :user_file, @user_file)
    project_file = Keyword.get(opts, :project_file, @project_file)
    env_prefix = Keyword.get(opts, :env_prefix, @env_prefix)

    project_props = read_file_silent(project_file)
    user_props = read_file_silent(user_file)
    env_props = read_env_vars(env_prefix)

    # Merge in order of lowest to highest precedence
    merged =
      project_props
      |> Map.merge(user_props)
      |> Map.merge(env_props)

    {:ok, merged}
  end

  defp read_file_silent(file_path) do
    expanded = Path.expand(file_path)

    if File.exists?(expanded) do
      case File.read(expanded) do
        {:ok, content} -> parse_properties(content)
        {:error, _} -> %{}
      end
    else
      %{}
    end
  end

  defp read_env_vars(prefix) do
    System.get_env()
    |> Enum.filter(fn {key, _value} -> String.starts_with?(key, prefix) end)
    |> Enum.map(&env_to_property(&1, prefix))
    |> Map.new()
  end

  # Converts TESTCONTAINERS_RYUK_CONTAINER_PRIVILEGED to ryuk.container.privileged
  defp env_to_property({key, value}, prefix) do
    property_key =
      key
      |> String.replace_prefix(prefix, "")
      |> String.downcase()
      |> String.replace("_", ".")

    {property_key, value}
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
