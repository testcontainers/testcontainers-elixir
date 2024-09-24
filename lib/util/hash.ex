defmodule Testcontainers.Util.Hash do
  def struct_to_hash(struct) when is_struct(struct) do
    :crypto.hash(:sha256, :erlang.term_to_binary(
      Enum.sort(Map.to_list(Map.from_struct(struct)))
    )) |> Base.encode16(case: :lower)
  end
end
