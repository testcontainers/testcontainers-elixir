defmodule TestcontainersTest do
  alias Testcontainers.Connection
  alias Testcontainers.Docker
  alias Testcontainers.MySqlContainer
  use ExUnit.Case, async: true

  @moduletag timeout: 300_000

  test "will cleanup containers" do
    {:ok, container} = Testcontainers.start_container(MySqlContainer.new())
    GenServer.stop(Testcontainers)
    TestHelper.wait_for_genserver_state(Testcontainers, :down)
    {:ok, _} = Testcontainers.start_link()

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
