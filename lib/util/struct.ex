defmodule Testcontainers.Util.ListFromDeepStruct do
  def from_deep_struct(%{} = map), do: convert(map)

  defp convert(%Regex{} = data) do
    Regex.source(data)
  end

  defp convert(data) when is_tuple(data) do
    Tuple.to_list(data) |> convert()
  end

  defp convert(data) when is_list(data) do
    data
    # Recursively convert each list element
    |> Enum.map(&convert/1)
  end

  defp convert(data) when is_struct(data) do
    data
    |> Map.from_struct()
    # Recursively convert the struct (now a map)
    |> convert()
  end

  defp convert(data) when is_map(data) do
    data
    # Convert the map to a list of key-value tuples
    |> Map.to_list()
    # Filter out entries with nil values
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    # Recursively convert both keys and values
    |> Enum.map(fn {k, v} -> {k, convert(v)} end)
    # Sort the list to ensure deterministic order
    |> Enum.sort()
  end

  defp convert(other), do: other
end
