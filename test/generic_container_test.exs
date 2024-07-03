defmodule Testcontainers.GenericContainerTest do
  use ExUnit.Case, async: true

  import TestHelper, only: [port_open?: 2]

  test "can start and stop generic container" do
    config = %Testcontainers.Container{image: "redis:latest"}
    assert {:ok, container} = Testcontainers.start_container(config)
    assert :ok = Testcontainers.stop_container(container.container_id)
  end

  test "can start and stop generic container with network mode set to host" do
    config = %Testcontainers.Container{image: "redis:latest", network_mode: "host"}
    assert {:ok, container} = Testcontainers.start_container(config)
    Process.sleep(5000)
    with {:unix, :darwin} <- :os.type() do
      IO.puts("Testing network_mode=host doesn't work in macos!")
    end
    assert :ok = port_open?("127.0.0.1", 6379)
    assert :ok = Testcontainers.stop_container(container.container_id)
  end
end
