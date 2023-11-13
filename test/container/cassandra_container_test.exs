defmodule Testcontainers.Container.CassandraContainerTest do
  use ExUnit.Case, async: true

  import Testcontainers.ExUnit
  alias Testcontainers.CassandraContainer

  @moduletag timeout: 300_000

  @cassandra_container CassandraContainer.new()

  container(:cassandra, @cassandra_container)

  test "creates and starts cassandra container", %{cassandra: cassandra} do
    {:ok, conn} = Xandra.start_link(nodes: [CassandraContainer.connection_uri(cassandra)])
    # TODO
  end
end
