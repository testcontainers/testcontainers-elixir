defmodule Testcontainers.HttpWaitStrategyTest do
  alias Testcontainers.HttpWaitStrategy
  alias Testcontainers.Container
  use ExUnit.Case, async: true

  test "can wait for a http request and retrieve content" do
    port = 80

    config =
      %Container{image: "nginx:alpine"}
      |> Container.with_exposed_port(port)
      |> Container.with_waiting_strategy(HttpWaitStrategy.new("/", port))

    assert {:ok, container} = Testcontainers.start_container(config)

    host_port = Container.mapped_port(container, port)
    url = ~c"http://localhost:#{host_port}/"
    {:ok, {_status, _headers, body}} = :httpc.request(:get, {url, []}, [], [])
    assert to_string(body) =~ "Welcome to nginx!"

    assert :ok = Testcontainers.stop_container(container.container_id)
  end

  test "can wait for a specific status code" do
    port = 80

    config =
      %Container{image: "nginx:alpine"}
      |> Container.with_exposed_port(port)
      |> Container.with_waiting_strategy(
        HttpWaitStrategy.new("/", port, status_code: 200)
      )

    assert {:ok, container} = Testcontainers.start_container(config)
    assert :ok = Testcontainers.stop_container(container.container_id)
  end

  test "fails when status code does not match" do
    port = 80

    config =
      %Container{image: "nginx:alpine"}
      |> Container.with_exposed_port(port)
      |> Container.with_waiting_strategy(
        HttpWaitStrategy.new("/", port, status_code: 999, timeout: 5000, max_retries: 1)
      )

    assert {:error, _, %HttpWaitStrategy{}} = Testcontainers.start_container(config)
  end

  test "can use a custom match function" do
    port = 80

    config =
      %Container{image: "nginx:alpine"}
      |> Container.with_exposed_port(port)
      |> Container.with_waiting_strategy(
        HttpWaitStrategy.new("/", port,
          match: fn response -> response.body =~ "Welcome to nginx!" end
        )
      )

    assert {:ok, container} = Testcontainers.start_container(config)
    assert :ok = Testcontainers.stop_container(container.container_id)
  end

  test "fails when custom match function returns false" do
    port = 80

    config =
      %Container{image: "nginx:alpine"}
      |> Container.with_exposed_port(port)
      |> Container.with_waiting_strategy(
        HttpWaitStrategy.new("/", port,
          timeout: 5000,
          max_retries: 1,
          match: fn _response -> false end
        )
      )

    assert {:error, _, %HttpWaitStrategy{}} = Testcontainers.start_container(config)
  end
end
