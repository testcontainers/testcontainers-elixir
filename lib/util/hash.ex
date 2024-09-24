defmodule Testcontainers.Util.Hash do
  def struct_to_hash(struct) when is_struct(struct) do
    struct
    |> Map.from_struct()
    |> Enum.sort()
    |> Enum.map(fn {k, v} -> "#{k}:#{inspect(v)}" end)
    |> Enum.join("|")
    |> (&:crypto.hash(:sha256, &1)).()
    |> Base.encode16(case: :lower)
  end
end
