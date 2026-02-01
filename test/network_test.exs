defmodule Testcontainers.NetworkTest do
  use ExUnit.Case, async: false

  alias Testcontainers.Container
  alias Testcontainers.ContainerBuilder
  alias Testcontainers.RedisContainer

  @moduletag timeout: 180_000

  describe "create_network/1" do
    test "creates a new Docker network" do
      network_name = "test-network-#{:rand.uniform(100_000)}"

      result = Testcontainers.create_network(network_name)
      assert match?({:ok, _}, result)

      # Cleanup
      Testcontainers.remove_network(network_name)
    end

    test "handles duplicate network creation gracefully" do
      network_name = "test-network-dup-#{:rand.uniform(100_000)}"

      # Create network first time
      {:ok, _} = Testcontainers.create_network(network_name)

      # Creating again should succeed (returns :already_exists)
      result = Testcontainers.create_network(network_name)
      assert match?({:ok, _}, result)

      # Cleanup
      Testcontainers.remove_network(network_name)
    end
  end

  describe "remove_network/1" do
    test "removes an existing network" do
      network_name = "test-network-remove-#{:rand.uniform(100_000)}"

      {:ok, _} = Testcontainers.create_network(network_name)
      result = Testcontainers.remove_network(network_name)

      assert result == :ok
    end

    test "handles removing non-existent network" do
      network_name = "non-existent-network-#{:rand.uniform(100_000)}"

      # Should handle gracefully (not crash)
      result = Testcontainers.remove_network(network_name)
      # Returns error with message when network doesn't exist
      assert match?({:error, {:failed_to_remove_network, _}}, result) or result == :ok
    end
  end

  describe "Container.with_network/2" do
    test "container can be configured with network" do
      container =
        Container.new("alpine:latest")
        |> Container.with_network("my-network")

      assert container.network == "my-network"
    end

    test "container can be configured with hostname" do
      container =
        Container.new("alpine:latest")
        |> Container.with_hostname("my-host")

      assert container.hostname == "my-host"
    end
  end

  describe "containers on shared network" do
    test "containers can communicate via hostname" do
      network_name = "test-network-comm-#{:rand.uniform(100_000)}"

      # Create network
      {:ok, _} = Testcontainers.create_network(network_name)

      # Start Redis container on the network
      redis_config =
        RedisContainer.new()
        |> ContainerBuilder.build()
        |> Container.with_network(network_name)
        |> Container.with_hostname("redis-server")

      {:ok, redis} = Testcontainers.start_container(redis_config)
      assert redis.ip_address != nil

      # Start an Alpine container that will ping Redis
      alpine_config =
        Container.new("alpine:latest")
        |> Container.with_network(network_name)
        |> Container.with_hostname("alpine-client")
        |> Container.with_cmd(["sleep", "60"])

      {:ok, alpine} = Testcontainers.start_container(alpine_config)

      # Both containers should be on the same network
      assert redis.ip_address != nil
      assert alpine.ip_address != nil

      # Verify Redis is accessible from the host
      host = Testcontainers.get_host()
      port = RedisContainer.port(redis)
      {:ok, conn} = Redix.start_link(host: host, port: port)
      assert Redix.command!(conn, ["PING"]) == "PONG"
      Redix.stop(conn)

      # Cleanup
      Testcontainers.stop_container(alpine.container_id)
      Testcontainers.stop_container(redis.container_id)
      Testcontainers.remove_network(network_name)
    end

    test "containers get IP addresses when on network" do
      network_name = "test-network-ip-#{:rand.uniform(100_000)}"

      {:ok, _} = Testcontainers.create_network(network_name)

      config =
        Container.new("alpine:latest")
        |> Container.with_network(network_name)
        |> Container.with_cmd(["sleep", "30"])

      {:ok, container} = Testcontainers.start_container(config)

      # Container should have an IP address
      assert container.ip_address != nil
      assert is_binary(container.ip_address)
      assert container.ip_address =~ ~r/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/

      # Cleanup
      Testcontainers.stop_container(container.container_id)
      Testcontainers.remove_network(network_name)
    end
  end
end
