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
    |> Enum.map(&convert/1)  # Recursively convert each list element
  end

  defp convert(data) when is_struct(data) do
    data
    |> Map.from_struct()
    |> convert()  # Recursively convert the struct (now a map)
  end

  defp convert(data) when is_map(data) do
    data
    |> Map.to_list()         # Convert the map to a list of key-value tuples
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)  # Filter out entries with nil values
    |> Enum.map(fn {k, v} -> {k, convert(v)} end)  # Recursively convert both keys and values
    |> Enum.sort()  # Sort the list to ensure deterministic order
  end

  defp convert(other), do: other
end
