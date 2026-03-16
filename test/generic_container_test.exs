defmodule Testcontainers.GenericContainerTest do
  use ExUnit.Case, async: true

  require Logger

  import Testcontainers.Container, only: [is_os: 1]
  import TestHelper, only: [port_open?: 2]

  test "can start and stop generic container" do
    config = %Testcontainers.Container{image: "redis:latest"}
    assert {:ok, container} = Testcontainers.start_container(config)
    assert :ok = Testcontainers.stop_container(container.container_id)
  end

  # This doesnt work on rootless docker, because binding ports to host requires root (i guess)
  # run test with --exclude needs_root if you are running rootless
  # Also incompatible with DooD (Docker-outside-of-Docker) since host networking
  # binds to the Docker host, not the test container
  @tag :needs_root
  @tag :host_network
  test "can start and stop generic container with network mode set to host" do
    if not is_os(:linux) do
      Logger.warning("Host is not Linux, therefore not running network_mode test")
    else
      if Testcontainers.running_in_container?() do
        Logger.warning("Skipping host network test in DooD environment")
      else
        config = %Testcontainers.Container{image: "redis:latest", network_mode: "host"}
        assert {:ok, container} = Testcontainers.start_container(config)
        Process.sleep(5000)
        assert :ok = port_open?(Testcontainers.get_host(), 6379)
        assert :ok = Testcontainers.stop_container(container.container_id)
      end
    end
  end
end
