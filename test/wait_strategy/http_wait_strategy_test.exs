defmodule Testcontainers.HttpWaitStrategyTest do
  alias Testcontainers.HttpWaitStrategy
  use ExUnit.Case, async: true

  test "can wait a http request" do
    port = 80

    config =
      %Testcontainers.Container{image: "nginx:alpine"}
      |> Testcontainers.Container.with_exposed_port(port)
      |> Testcontainers.Container.with_waiting_strategy(HttpWaitStrategy.new("/", port))

    assert {:ok, container} = Testcontainers.start_container(config)
    assert :ok = Testcontainers.stop_container(container.container_id)
  end
end
