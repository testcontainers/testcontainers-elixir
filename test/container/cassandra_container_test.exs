defmodule Testcontainers.Container.CassandraContainerTest do
  use ExUnit.Case, async: true

  import Testcontainers.ExUnit
  alias Testcontainers.CassandraContainer

  @moduletag timeout: 300_000

  @cassandra_container CassandraContainer.new()

  test "cassandra defaults" do
    assert CassandraContainer.default_port() == 9042
    assert CassandraContainer.default_image() == "cassandra"
    assert CassandraContainer.get_username() == "cassandra"
    assert CassandraContainer.get_password() == "cassandra"
  end

  describe "cassandra" do
    container(:cassandra, @cassandra_container)

    test "can create and start", %{cassandra: cassandra} do
      {:ok, conn} = Xandra.start_link(nodes: [CassandraContainer.connection_uri(cassandra)])

      {:ok, _result} =
        Xandra.execute(
          conn,
          "CREATE KEYSPACE cassandra_test WITH replication = {'class':'SimpleStrategy', 'replication_factor' : 3}"
        )

      {:ok, _result} =
        Xandra.execute(
          conn,
          "CREATE TABLE cassandra_test.users (id int PRIMARY KEY, name varchar)"
        )

      {:ok, _result} =
        Xandra.execute(
          conn,
          "INSERT INTO cassandra_test.users(id, name) VALUES(1, 'Very special name')"
        )

      {:ok, _result} =
        Xandra.execute(
          conn,
          "INSERT INTO cassandra_test.users(id, name) VALUES(2, 'Other name')"
        )

      page =
        with {:ok, prepared} <-
               Xandra.prepare(
                 conn,
                 "SELECT * FROM cassandra_test.users WHERE name = ? ALLOW FILTERING"
               ),
             {:ok, %Xandra.Page{} = page} <-
               Xandra.execute(conn, prepared, [_name = "Very special name"]),
             do: page

      assert length(page.content) == 1
      assert page.content |> Kernel.hd() |> List.last() == "Very special name"
    end
  end
end
