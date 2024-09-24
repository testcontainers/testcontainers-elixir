defmodule Testcontainers.Util.Hash do
  alias Testcontainers.Util.ListFromDeepStruct

  def struct_to_hash(struct) when is_struct(struct) do
    struct
    |> ListFromDeepStruct.from_deep_struct()
    |> Kernel.then(&inspect(&1))
    |> (&:crypto.hash(:sha256, &1)).()
    |> Base.encode16(case: :lower)
  end
end
