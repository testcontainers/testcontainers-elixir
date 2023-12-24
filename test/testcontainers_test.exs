defmodule TestcontainersTest do
  alias Testcontainers.Connection
  alias Testcontainers.Docker
  alias Testcontainers.MySqlContainer
  use ExUnit.Case, async: true

  @moduletag timeout: 300_000

  test "will cleanup containers" do
    {:ok, pid} = Testcontainers.start_link(name: :cleanup_test1)
    {:ok, container} = Testcontainers.start_container(MySqlContainer.new(), pid)
    :ok = GenServer.stop(pid)
    :ok = TestHelper.wait_for_genserver_state(:cleanup_test1, :down)

    :ok =
      TestHelper.wait_for_lambda(
        fn ->
          with {:error, _} <-
                 Docker.Api.get_container(
                   container.container_id,
                   Connection.get_connection() |> Tuple.to_list() |> Kernel.hd()
                 ),
               do: :ok
        end,
        max_retries: 15,
        interval: 1000
      )
  end
end
