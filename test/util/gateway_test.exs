defmodule Testcontainers.GatewayTest do
  use ExUnit.Case, async: true

  alias Testcontainers.Connection
  import Testcontainers.GatewayUtil

  test "will get gateway address if in docker environment" do
    {conn, docker_host_url} = Connection.get_connection()

    {:ok, gateway_address} =
      get_docker_host(docker_host_url, conn, dockerenv: "test/util/.dockerenv")

    assert gateway_address != "localhost"
  end

  test "will get gateway address if not in docker environment" do
    {conn, docker_host_url} = Connection.get_connection()

    {:ok, gateway_address} =
      get_docker_host(docker_host_url, conn, dockerenv: "foobar/doesnotexist")

    assert gateway_address == "localhost"
  end
end
