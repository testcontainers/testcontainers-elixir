# SPDX-License-Identifier: MIT
defmodule Testcontainers.Container.ToxiproxyContainerTest do
  use ExUnit.Case, async: true
  import Testcontainers.ExUnit

  alias Testcontainers.Container
  alias Testcontainers.ToxiproxyContainer

  @moduletag timeout: 120_000

  describe "new/0" do
    test "creates a new ToxiproxyContainer struct with default configurations" do
      config = ToxiproxyContainer.new()

      assert config.image == "ghcr.io/shopify/toxiproxy:2.9.0"
      assert config.wait_timeout == 60_000
      assert config.reuse == false
    end
  end

  describe "with_image/2" do
    test "overrides the default image" do
      config = ToxiproxyContainer.new()
      new_config = ToxiproxyContainer.with_image(config, "ghcr.io/shopify/toxiproxy:2.8.0")

      assert new_config.image == "ghcr.io/shopify/toxiproxy:2.8.0"
    end

    test "raises if the image is not a binary" do
      config = ToxiproxyContainer.new()
      assert_raise FunctionClauseError, fn -> ToxiproxyContainer.with_image(config, 123) end
    end
  end

  describe "with_wait_timeout/2" do
    test "overrides the default wait timeout" do
      config = ToxiproxyContainer.new()
      new_config = ToxiproxyContainer.with_wait_timeout(config, 30_000)

      assert new_config.wait_timeout == 30_000
    end

    test "raises if the wait timeout is not an integer" do
      config = ToxiproxyContainer.new()

      assert_raise FunctionClauseError, fn ->
        ToxiproxyContainer.with_wait_timeout(config, "30000")
      end
    end
  end

  describe "with_reuse/2" do
    test "sets the reuse flag to true" do
      config = ToxiproxyContainer.new()
      new_config = ToxiproxyContainer.with_reuse(config, true)

      assert new_config.reuse == true
    end

    test "sets the reuse flag to false" do
      config =
        ToxiproxyContainer.new()
        |> ToxiproxyContainer.with_reuse(true)
        |> ToxiproxyContainer.with_reuse(false)

      assert config.reuse == false
    end

    test "raises if reuse is not a boolean" do
      config = ToxiproxyContainer.new()

      assert_raise FunctionClauseError, fn ->
        ToxiproxyContainer.with_reuse(config, "true")
      end
    end
  end

  describe "default_image/0" do
    test "returns the default image with tag" do
      assert ToxiproxyContainer.default_image() == "ghcr.io/shopify/toxiproxy:2.9.0"
    end
  end

  describe "control_port/0" do
    test "returns the control port" do
      assert ToxiproxyContainer.control_port() == 8474
    end
  end

  describe "first_proxy_port/0" do
    test "returns the first proxy port" do
      assert ToxiproxyContainer.first_proxy_port() == 8666
    end
  end

  describe "proxy_port_count/0" do
    test "returns the number of proxy ports" do
      assert ToxiproxyContainer.proxy_port_count() == 31
    end
  end

  describe "with default configuration" do
    container(:toxiproxy, ToxiproxyContainer.new())

    test "provides a ready-to-use toxiproxy container", %{toxiproxy: toxiproxy} do
      # Verify the container is running and has the expected ports
      assert toxiproxy.container_id != nil

      # Verify control port is mapped
      control_port = Container.mapped_port(toxiproxy, ToxiproxyContainer.control_port())
      assert is_integer(control_port)
      assert control_port > 0

      # Verify first proxy port is mapped
      proxy_port = Container.mapped_port(toxiproxy, ToxiproxyContainer.first_proxy_port())
      assert is_integer(proxy_port)
      assert proxy_port > 0
    end

    test "can access toxiproxy API", %{toxiproxy: toxiproxy} do
      :inets.start()

      host = Testcontainers.get_host()
      port = ToxiproxyContainer.mapped_control_port(toxiproxy)
      url = ~c"http://#{host}:#{port}/version"

      {:ok, {{_, 200, _}, _, body}} = :httpc.request(:get, {url, []}, [], [])
      assert to_string(body) =~ "2.9.0"
    end

    test "api_url/1 returns correct URL", %{toxiproxy: toxiproxy} do
      url = ToxiproxyContainer.api_url(toxiproxy)

      assert url =~ "http://"
      assert url =~ ":#{ToxiproxyContainer.mapped_control_port(toxiproxy)}"
    end

    test "configure_toxiproxy_ex/1 sets application env", %{toxiproxy: toxiproxy} do
      :ok = ToxiproxyContainer.configure_toxiproxy_ex(toxiproxy)

      assert Application.get_env(:toxiproxy_ex, :host) == ToxiproxyContainer.api_url(toxiproxy)
    end

    test "can create and list proxies", %{toxiproxy: toxiproxy} do
      # Use unique proxy name and port to avoid conflicts with concurrent tests
      proxy_name = "test_proxy_#{:rand.uniform(100_000)}"
      listen_port = ToxiproxyContainer.first_proxy_port() + 1

      # Ensure cleanup always happens
      on_exit(fn ->
        ToxiproxyContainer.delete_proxy(toxiproxy, proxy_name)
      end)

      # Create a proxy
      {:ok, proxy_port} =
        ToxiproxyContainer.create_proxy(toxiproxy, proxy_name, "localhost:12345",
          listen_port: listen_port
        )

      assert is_integer(proxy_port)

      # List proxies
      {:ok, proxies} = ToxiproxyContainer.list_proxies(toxiproxy)
      assert Map.has_key?(proxies, proxy_name)
      assert proxies[proxy_name]["upstream"] == "localhost:12345"

      # Delete proxy
      :ok = ToxiproxyContainer.delete_proxy(toxiproxy, proxy_name)

      # Verify deleted
      {:ok, proxies_after} = ToxiproxyContainer.list_proxies(toxiproxy)
      refute Map.has_key?(proxies_after, proxy_name)
    end

    test "create_proxy/4 handles already existing proxy", %{toxiproxy: toxiproxy} do
      # Use unique proxy name and port to avoid conflicts with concurrent tests
      proxy_name = "duplicate_proxy_#{:rand.uniform(100_000)}"
      listen_port = ToxiproxyContainer.first_proxy_port() + 2

      # Ensure cleanup always happens
      on_exit(fn ->
        ToxiproxyContainer.delete_proxy(toxiproxy, proxy_name)
      end)

      # Create proxy twice - second should succeed (409 is handled)
      {:ok, _} =
        ToxiproxyContainer.create_proxy(toxiproxy, proxy_name, "localhost:54321",
          listen_port: listen_port
        )

      {:ok, _} =
        ToxiproxyContainer.create_proxy(toxiproxy, proxy_name, "localhost:54321",
          listen_port: listen_port
        )
    end

    test "delete_proxy/2 returns error for non-existent proxy", %{toxiproxy: toxiproxy} do
      assert {:error, :not_found} =
               ToxiproxyContainer.delete_proxy(toxiproxy, "non_existent_proxy")
    end

    test "reset/1 clears all toxics", %{toxiproxy: toxiproxy} do
      # Use unique proxy name and port to avoid conflicts with concurrent tests
      proxy_name = "reset_test_proxy_#{:rand.uniform(100_000)}"
      listen_port = ToxiproxyContainer.first_proxy_port() + 3

      # Ensure cleanup always happens
      on_exit(fn ->
        ToxiproxyContainer.delete_proxy(toxiproxy, proxy_name)
      end)

      # Create a proxy
      {:ok, _} =
        ToxiproxyContainer.create_proxy(toxiproxy, proxy_name, "localhost:11111",
          listen_port: listen_port
        )

      # Reset should succeed
      :ok = ToxiproxyContainer.reset(toxiproxy)
    end
  end

  describe "create_proxy_for_container/5" do
    container(:toxiproxy, ToxiproxyContainer.new())

    test "creates proxy using container IP", %{toxiproxy: toxiproxy} do
      # Use unique proxy name and port to avoid conflicts with concurrent tests
      proxy_name = "container_proxy_#{:rand.uniform(100_000)}"
      unique_listen_port = ToxiproxyContainer.first_proxy_port() + :rand.uniform(20)

      # Create a mock container struct with IP
      mock_container = %Container{
        container_id: "mock_id",
        image: "mock:latest",
        ip_address: "172.17.0.5",
        exposed_ports: []
      }

      # Ensure cleanup always happens
      on_exit(fn ->
        ToxiproxyContainer.delete_proxy(toxiproxy, proxy_name)
      end)

      {:ok, proxy_port} =
        ToxiproxyContainer.create_proxy_for_container(
          toxiproxy,
          proxy_name,
          mock_container,
          6379,
          listen_port: unique_listen_port
        )

      assert is_integer(proxy_port)

      # Verify the upstream is correct
      {:ok, proxies} = ToxiproxyContainer.list_proxies(toxiproxy)
      assert proxies[proxy_name]["upstream"] == "172.17.0.5:6379"
    end
  end

  describe "integration with real container (Redis)" do
    @redis_port 6379

    setup do
      # Create a unique network for container communication
      network_name = "toxiproxy-integration-#{:rand.uniform(100_000)}"
      {:ok, _} = Testcontainers.create_network(network_name)

      on_exit(fn ->
        Testcontainers.remove_network(network_name)
      end)

      {:ok, network_name: network_name}
    end

    test "can proxy and inject faults into Redis traffic", %{network_name: network_name} do
      alias Testcontainers.RedisContainer
      alias Testcontainers.ContainerBuilder

      # Start Redis on the network
      redis_config =
        RedisContainer.new()
        |> ContainerBuilder.build()
        |> Container.with_network(network_name)
        |> Container.with_hostname("redis")

      {:ok, redis} = Testcontainers.start_container(redis_config)

      # Start Toxiproxy on the same network
      toxiproxy_config =
        ToxiproxyContainer.new()
        |> ContainerBuilder.build()
        |> Container.with_network(network_name)
        |> Container.with_hostname("toxiproxy")

      {:ok, toxiproxy} = Testcontainers.start_container(toxiproxy_config)

      # Create proxy from Toxiproxy to Redis
      {:ok, proxy_port} =
        ToxiproxyContainer.create_proxy_for_container(
          toxiproxy,
          "redis_integration",
          redis,
          @redis_port
        )

      # Configure ToxiproxyEx client
      :ok = ToxiproxyContainer.configure_toxiproxy_ex(toxiproxy)

      # Connect to Redis through the proxy
      host = Testcontainers.get_host()
      {:ok, conn} = Redix.start_link(host: host, port: proxy_port)

      # Verify normal operation through proxy
      assert Redix.command!(conn, ["PING"]) == "PONG"
      assert Redix.command!(conn, ["SET", "test_key", "test_value"]) == "OK"
      assert Redix.command!(conn, ["GET", "test_key"]) == "test_value"

      # Inject latency and verify it affects response time
      ToxiproxyEx.get!("redis_integration")
      |> ToxiproxyEx.toxic(:latency, latency: 500)
      |> ToxiproxyEx.apply!(fn ->
        {time_us, result} =
          :timer.tc(fn ->
            Redix.command!(conn, ["PING"])
          end)

        assert result == "PONG"
        # Should take at least 400ms (allowing some tolerance)
        assert time_us > 400_000, "Expected > 400ms latency, got #{time_us / 1000}ms"
      end)

      # Take down proxy and verify connection fails
      ToxiproxyEx.get!("redis_integration")
      |> ToxiproxyEx.down!(fn ->
        result = Redix.command(conn, ["PING"])
        assert match?({:error, _}, result), "Expected error when proxy is down"
      end)

      # After proxy re-enabled, new connection should work
      Redix.stop(conn)
      {:ok, conn2} = Redix.start_link(host: host, port: proxy_port)
      assert Redix.command!(conn2, ["PING"]) == "PONG"
      assert Redix.command!(conn2, ["GET", "test_key"]) == "test_value"

      Redix.stop(conn2)
    end
  end
end
