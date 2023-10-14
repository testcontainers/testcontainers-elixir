defmodule TestcontainersElixir.RedisContainerTest do
  use ExUnit.Case, async: true
  import TestcontainersElixir.ExUnit

  alias TestcontainersElixir.Container.RedisContainer

  describe "with default configuration" do
    container(:redis, RedisContainer.new())

    test "provides a ready-to-use redis container", %{redis: redis} do
      {:ok, conn} = Redix.start_link(RedisContainer.connection_url(redis))

      assert Redix.command!(conn, ["PING"]) == "PONG"
    end
  end
end
