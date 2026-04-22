defmodule TestcontainersTest do
  alias Testcontainers.Connection
  alias Testcontainers.Container
  alias Testcontainers.Docker
  # async: false because ryuk_privileged? tests mutate process environment
  use ExUnit.Case, async: false

  @ryuk_privileged_env "TESTCONTAINERS_RYUK_CONTAINER_PRIVILEGED"
  @ryuk_privileged_prop "ryuk.container.privileged"

  describe "ryuk_privileged?/1" do
    setup do
      original = System.get_env(@ryuk_privileged_env)

      on_exit(fn ->
        case original do
          nil -> System.delete_env(@ryuk_privileged_env)
          value -> System.put_env(@ryuk_privileged_env, value)
        end
      end)

      :ok
    end

    test "returns false when neither property nor env var is set" do
      System.delete_env(@ryuk_privileged_env)
      refute Testcontainers.ryuk_privileged?(%{})
    end

    test "returns true when property is 'true'" do
      System.delete_env(@ryuk_privileged_env)
      assert Testcontainers.ryuk_privileged?(%{@ryuk_privileged_prop => "true"})
    end

    test "returns true when property is '1'" do
      System.delete_env(@ryuk_privileged_env)
      assert Testcontainers.ryuk_privileged?(%{@ryuk_privileged_prop => "1"})
    end

    test "returns false when property is 'false'" do
      System.delete_env(@ryuk_privileged_env)
      refute Testcontainers.ryuk_privileged?(%{@ryuk_privileged_prop => "false"})
    end

    test "returns false when property is '0'" do
      System.delete_env(@ryuk_privileged_env)
      refute Testcontainers.ryuk_privileged?(%{@ryuk_privileged_prop => "0"})
    end

    test "returns true when env var is 'true'" do
      System.put_env(@ryuk_privileged_env, "true")
      assert Testcontainers.ryuk_privileged?(%{})
    end

    test "returns true when env var is '1'" do
      System.put_env(@ryuk_privileged_env, "1")
      assert Testcontainers.ryuk_privileged?(%{})
    end

    test "returns false when env var is 'false'" do
      System.put_env(@ryuk_privileged_env, "false")
      refute Testcontainers.ryuk_privileged?(%{@ryuk_privileged_prop => "true"})
    end

    test "env var takes precedence over property (env false, prop true)" do
      System.put_env(@ryuk_privileged_env, "false")
      refute Testcontainers.ryuk_privileged?(%{@ryuk_privileged_prop => "true"})
    end

    test "env var takes precedence over property (env true, prop false)" do
      System.put_env(@ryuk_privileged_env, "true")
      assert Testcontainers.ryuk_privileged?(%{@ryuk_privileged_prop => "false"})
    end

    test "treats arbitrary strings as falsy" do
      System.delete_env(@ryuk_privileged_env)
      refute Testcontainers.ryuk_privileged?(%{@ryuk_privileged_prop => "yes"})
      refute Testcontainers.ryuk_privileged?(%{@ryuk_privileged_prop => ""})
    end

    test "is case-insensitive and trims whitespace" do
      System.delete_env(@ryuk_privileged_env)
      assert Testcontainers.ryuk_privileged?(%{@ryuk_privileged_prop => "TRUE"})
      assert Testcontainers.ryuk_privileged?(%{@ryuk_privileged_prop => "  true  "})
    end
  end

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
