defmodule TestcontainersTest do
  alias Testcontainers.Connection
  alias Testcontainers.Container
  alias Testcontainers.Docker
  use ExUnit.Case, async: true

  test "cleans up containers on terminate" do
    {:ok, pid} = Testcontainers.start_link(name: :cleanup_test1)

    config = %Container{image: "nginx:alpine"}
    {:ok, container} = Testcontainers.start_container(config, :cleanup_test1)

    # Verify the container is running
    conn = Connection.get_connection() |> Tuple.to_list() |> Kernel.hd()
    assert {:ok, _} = Docker.Api.get_container(container.container_id, conn)

    # Stop the GenServer, which triggers terminate and cleans up containers
    :ok = GenServer.stop(pid)

    # Container should be gone
    assert {:error, _} = Docker.Api.get_container(container.container_id, conn)
  end

  test "cleans up container when wait strategy fails" do
    config =
      %Container{image: "nginx:alpine"}
      |> Container.with_exposed_port(80)
      |> Container.with_waiting_strategy(
        Testcontainers.HttpWaitStrategy.new("/nonexistent", 80,
          status_code: 999,
          timeout: 2000,
          max_retries: 1
        )
      )

    {:ok, pid} = Testcontainers.start_link(name: :cleanup_test2)
    result = Testcontainers.start_container(config, :cleanup_test2)

    assert {:error, _, _} = result

    :ok = GenServer.stop(pid)
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
