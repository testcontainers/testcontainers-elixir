# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule Testcontainers.Container.RedisContainerTest do
  use ExUnit.Case, async: true
  import Testcontainers.ExUnit

  alias Testcontainers.Container.RedisContainer

  @moduletag timeout: 120_000

  describe "with default configuration" do
    container(:redis, RedisContainer.new())

    test "provides a ready-to-use redis container", %{redis: redis} do
      {:ok, conn} = Redix.start_link(RedisContainer.connection_url(redis))

      assert Redix.command!(conn, ["PING"]) == "PONG"
    end
  end
end
