# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule Testcontainers.Container.PostgresContainerTest do
  use ExUnit.Case, async: true
  import Testcontainers.ExUnit

  alias Testcontainers.PostgresContainer

  @moduletag timeout: 300_000

  describe "with default configuration" do
    container(:postgres, PostgresContainer.new())

    test "provides a ready-to-use postgres container", %{postgres: postgres} do
      {:ok, pid} = Postgrex.start_link(PostgresContainer.connection_parameters(postgres))

      assert %{num_rows: 1} = Postgrex.query!(pid, "SELECT 1", [])
    end
  end

  describe "with custom configuration" do
    import PostgresContainer

    @custom_postgres new()
                     |> with_image("postgres:12.1")
                     |> with_user("custom-user")
                     |> with_password("custom-password")
                     |> with_database("custom-database")

    container(:postgres, @custom_postgres)

    test "provides a postgres container compliant with specified configuration", %{
      postgres: postgres
    } do
      {:ok, pid} = Postgrex.start_link(PostgresContainer.connection_parameters(postgres))

      query_result = Postgrex.query!(pid, "SELECT version()", [])

      version_info = query_result.rows |> Enum.at(0) |> Enum.at(0)
      assert version_info =~ "PostgreSQL 12.1"
    end
  end
end
