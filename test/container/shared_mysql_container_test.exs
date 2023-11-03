# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule Testcontainers.Container.SharedMySqlContainerTest do
  use ExUnit.Case, async: true

  import Testcontainers.ExUnit

  alias Testcontainers.MySqlContainer

  @moduletag timeout: 300_000

  container(:mysql, MySqlContainer.new(), shared: true)

  test "can select 1", %{mysql: mysql} do
    params =
      MySqlContainer.connection_parameters(mysql)
      |> Keyword.merge(queue_target: 30_000, queue_interval: 30_000)

    {:ok, pid} = MyXQL.start_link(params)

    assert %{num_rows: 1} = MyXQL.query!(pid, "SELECT 1", [])
  end

  test "can check version", %{mysql: mysql} do
    params =
      MySqlContainer.connection_parameters(mysql)
      |> Keyword.merge(queue_target: 30_000, queue_interval: 30_000)

    {:ok, pid} = MyXQL.start_link(params)

    query_result = MyXQL.query!(pid, "SELECT version()", [])

    version_info = query_result.rows |> Enum.at(0) |> Enum.at(0)
    assert version_info =~ "8"
  end
end
