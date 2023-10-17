# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule Testcontainers.Container.PostgresContainerTest do
  use ExUnit.Case, async: true
  import Testcontainers.ExUnit

  alias Testcontainers.Container.PostgresContainer

  @moduletag timeout: 300_000

  describe "with default configuration" do
    container(:postgres, PostgresContainer.new())

    test "provides a ready-to-use postgres container", %{postgres: postgres} do
      {:ok, pid} = Postgrex.start_link(PostgresContainer.connection_parameters(postgres))

      assert %{num_rows: 1} = Postgrex.query!(pid, "SELECT 1", [])
    end
  end

  describe "with custom configuration" do
    @custom_postgres PostgresContainer.new("postgres:12.1",
                       username: "custom-user",
                       password: "custom-password",
                       database: "custom-database"
                     )

    container(:postgres, @custom_postgres)

    test "provides a postgres container compliant with specified configuration", %{
      postgres: postgres
    } do
      {:ok, pid} =
        Postgrex.start_link(
          username: "custom-user",
          password: "custom-password",
          database: "custom-database",
          hostname: "localhost",
          port: PostgresContainer.port(postgres)
        )

      query_result = Postgrex.query!(pid, "SELECT version()", [])

      version_info = query_result.rows |> Enum.at(0) |> Enum.at(0)
      assert version_info =~ "PostgreSQL 12.1"
    end
  end
end
