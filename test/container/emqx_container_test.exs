defmodule Testcontainers.Container.EmqxContainerTest do
  use ExUnit.Case, async: true
  import Testcontainers.ExUnit

  alias Testcontainers.EmqxContainer

  @moduletag timeout: 300_000

  describe "with default and minimal configuration" do
    container(:emqx, EmqxContainer.new())

    test "provides a ready-to-use emqx container", %{emqx: emqx} do
      host = EmqxContainer.host()
      port = EmqxContainer.mqtt_port(emqx)
      {:ok, _pid} = ExMQTT.start_link(host: host, port: port)
    end
  end

  describe "with custom configuration" do
    container(
      :emqx,
      EmqxContainer.new()
      |> EmqxContainer.with_image("emqx:5.5.1")
      |> EmqxContainer.with_ports(1884, 8883, 8083, 8084, 18084)
    )

    test "provides a ready-to-use emqx container" do
      host = EmqxContainer.host()
      port = 1884
      {:ok, _pid} = ExMQTT.start_link(host: host, port: port)
    end
  end
end
