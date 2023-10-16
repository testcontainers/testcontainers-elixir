defmodule Testcontainers.RedisContainerTest do
  use ExUnit.Case, async: true
  import Testcontainers.ExUnit

  alias Testcontainers.Container.RedisContainer

  @tag timeout: 120_000

  describe "with default configuration" do
    container(:redis, RedisContainer.new())

    test "provides a ready-to-use redis container", %{redis: redis} do
      {:ok, conn} = Redix.start_link(RedisContainer.connection_url(redis))

      assert Redix.command!(conn, ["PING"]) == "PONG"
    end
  end
end
