defmodule Testcontainers.Util.Hash do
  def struct_to_hash(struct) when is_struct(struct) do
    struct
    |> Nestru.encode!()
    |> Jason.encode!()
    |> IO.inspect()
    |> (&:crypto.hash(:sha256, &1)).()
    |> Base.encode16(case: :lower)
  end
end

defimpl Nestru.Encoder, for: Regex do
  def gather_fields_from_struct(regex, _context) do
    {:ok, Regex.source(regex)}
  end
end
