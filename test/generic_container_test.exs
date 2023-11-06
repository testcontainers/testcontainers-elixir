defmodule Testcontainers.GenericContainerTest do
  use ExUnit.Case, async: true

  test "can start and stop generic container" do
    config = %Testcontainers.Container{image: "redis:latest"}
    assert {:ok, container} = Testcontainers.start_container(config)
    assert :ok = Testcontainers.stop_container(container.container_id)
  end
end
