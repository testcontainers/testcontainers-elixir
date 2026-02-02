defmodule TestcontainersTest do
  alias Testcontainers.Connection
  alias Testcontainers.Docker
  alias Testcontainers.MySqlContainer
  use ExUnit.Case, async: true

  @moduletag timeout: 300_000

  @tag :flaky
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

  test "initializes successfully when ryuk is disabled" do
    # Set environment variable to disable Ryuk
    System.put_env("TESTCONTAINERS_RYUK_DISABLED", "true")

    try do
      # This should succeed without errors when Ryuk is disabled
      # The fix ensures start_reaper returns {:ok} instead of {:ok, nil}
      # which matches the pattern in the with statement
      {:ok, _pid} = Testcontainers.start_link(name: :ryuk_disabled_test)

      # If we reach here, the initialization succeeded
      assert true
    after
      # Clean up the environment variable
      System.delete_env("TESTCONTAINERS_RYUK_DISABLED")
    end
  end
end
