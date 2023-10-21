# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule Testcontainers.Container.MongodbContainerTest do
  use ExUnit.Case, async: true
  import Testcontainers.ExUnit

  alias Testcontainers.Container.MongodbContainer

  @moduletag timeout: 60_000

  describe "with default configuration" do
    container(:mongodb, MongodbContainer.new())

    test "provides a ready-to-use mongodb container", %{mongodb: mongodb} do
      assert mongodb.environment[:MONGO_MAJOR] == "7.0"
      assert is_integer(MongodbContainer.port(mongodb))
      assert MongodbContainer.port(mongodb) != MongodbContainer.default_port()
    end
  end
end
