defmodule Testcontainers.Util.Hash do
  def struct_to_hash(struct) when is_struct(struct) do
    struct
    |> Nestru.encode!()
    |> Jason.encode!()
    |> (&:crypto.hash(:sha256, &1)).()
    |> Base.encode16(case: :lower)
  end
end

defimpl Nestru.Encoder, for: Regex do
  def gather_fields_from_struct(regex, _context) do
    {:ok, Regex.source(regex)}
  end
end

defimpl Nestru.Encoder, for: Tuple do
  @spec gather_fields_from_struct(tuple(), any()) :: {:ok, binary()}
  def gather_fields_from_struct(tuple, _context) do
    {:ok, inspect(tuple)}
  end
end

defimpl Jason.Encoder, for: Tuple do
  def encode(tuple, opts) do
    Jason.Encode.string(inspect(tuple), opts)
  end
end
