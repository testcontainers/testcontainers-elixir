defmodule Testcontainers.GenericContainerTest do
  use ExUnit.Case, async: true

  import TestHelper, only: [port_open?: 1]

  test "can start and stop generic container" do
    config = %Testcontainers.Container{image: "redis:latest"}
    assert {:ok, container} = Testcontainers.start_container(config)
    assert :ok = Testcontainers.stop_container(container.container_id)
  end

  test "can start and stop generic container with network mode set to host" do
    config = %Testcontainers.Container{image: "redis:latest", network_mode: "host"}
    assert {:ok, container} = Testcontainers.start_container(config)
    Process.sleep(5000)
    assert :ok = port_open?(6379)
    assert :ok = Testcontainers.stop_container(container.container_id)
  end
end
