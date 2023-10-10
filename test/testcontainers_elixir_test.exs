defmodule TestcontainersElixirTest do
  use ExUnit.Case
  doctest TestcontainersElixir

  test "greets the world" do
    assert TestcontainersElixir.hello() == "{\"message\":\"Hello World\"}"
  end
end
