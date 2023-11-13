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
      {:ok, _conn} = Xandra.start_link(nodes: [CassandraContainer.connection_uri(cassandra)])
      # TODO
    end
  end
end
