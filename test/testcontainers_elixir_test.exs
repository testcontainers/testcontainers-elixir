defmodule TestcontainersElixirTest do
  use ExUnit.Case
  doctest TestcontainersElixir

  test "greets the world" do
    {:ok, list} = TestcontainersElixir.hello()
    assert is_number(length(list))
  end
end
