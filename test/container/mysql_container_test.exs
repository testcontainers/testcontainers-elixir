# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule Testcontainers.Container.MySqlContainerTest do
  use ExUnit.Case, async: true

  import Testcontainers.ExUnit

  alias Testcontainers.MySqlContainer

  @moduletag timeout: 300_000

  describe "with default configuration" do
    @mysql_container MySqlContainer.new()

    container(:mysql, @mysql_container)

    test "provides a ready-to-use mysql container", %{mysql: mysql} do
      params =
        MySqlContainer.connection_parameters(mysql)
        |> Keyword.merge(queue_target: 30_000, queue_interval: 30_000)

      {:ok, pid} = MyXQL.start_link(params)

      assert %{num_rows: 1} = MyXQL.query!(pid, "SELECT 1", [])
    end
  end

  describe "with custom configuration" do
    import MySqlContainer

    @custom_mysql_container new()
                            |> with_user("custom-user")
                            |> with_password("custom-password")
                            |> with_database("custom-database")

    container(:mysql, @custom_mysql_container)

    test "provides a mysql container compliant with specified configuration", %{mysql: mysql} do
      params =
        MySqlContainer.connection_parameters(mysql)
        |> Keyword.merge(queue_target: 30_000, queue_interval: 30_000)

      {:ok, pid} = MyXQL.start_link(params)

      assert %{num_rows: 1} = MyXQL.query!(pid, "SELECT 1", [])
    end
  end
end
