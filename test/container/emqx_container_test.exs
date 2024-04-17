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
end
