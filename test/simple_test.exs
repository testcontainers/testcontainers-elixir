defmodule SimpleTest do
  use ExUnit.Case
  import TestcontainersElixir.ExUnit

  test "creates and reapes container" do
    {:ok, container_id} = container(image: "nginx:latest", port: 80)
    assert is_binary(container_id)
  end
end
