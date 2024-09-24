defmodule Testcontainers.Util.Hash do
  def struct_to_hash(struct) when is_struct(struct) do
    struct
    |> Map.from_struct()
    |> Map.to_list()
    |> Enum.sort()
    |> Jason.encode!()
    |> IO.inspect()
    |> (&:crypto.hash(:sha256, &1)).()
    |> Base.encode16(case: :lower)
  end
end
