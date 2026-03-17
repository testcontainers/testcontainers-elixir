defmodule Hello.DockerComposeTest do
  use ExUnit.Case, async: false

  alias Testcontainers.DockerCompose
  alias Testcontainers.Compose.ComposeEnvironment

  @compose_path Path.expand("../docker-compose.yml", __DIR__)

  describe "multi-service compose" do
    setup do
      compose = DockerCompose.new(@compose_path)
      {:ok, env} = Testcontainers.start_compose(compose)
      on_exit(fn -> Testcontainers.stop_compose(env) end)
      %{env: env}
    end

    test "starts both postgres and redis", %{env: env} do
      assert %ComposeEnvironment{} = env

      # Verify postgres
      pg_service = ComposeEnvironment.get_service(env, "postgres")
      assert pg_service.service_name == "postgres"
      assert pg_service.state == "running"

      pg_host = ComposeEnvironment.get_service_host(env, "postgres")
      pg_port = ComposeEnvironment.get_service_port(env, "postgres", 5432)

      {:ok, pid} =
        Postgrex.start_link(
          hostname: pg_host,
          port: pg_port,
          username: "postgres",
          password: "postgres",
          database: "hello_compose_test"
        )

      assert {:ok, %Postgrex.Result{num_rows: 1}} = Postgrex.query(pid, "SELECT 1", [])
      GenServer.stop(pid)

      # Verify redis
      redis_service = ComposeEnvironment.get_service(env, "redis")
      assert redis_service.service_name == "redis"
      assert redis_service.state == "running"

      redis_host = ComposeEnvironment.get_service_host(env, "redis")
      redis_port = ComposeEnvironment.get_service_port(env, "redis", 6379)

      {:ok, conn} = :gen_tcp.connect(~c"#{redis_host}", redis_port, [:binary, active: false], 5000)
      :gen_tcp.send(conn, "PING\r\n")
      {:ok, response} = :gen_tcp.recv(conn, 0, 5000)
      assert response =~ "PONG"
      :gen_tcp.close(conn)
    end
  end
end

defmodule Hello.DockerComposeSharedTest do
  use ExUnit.Case, async: false

  import Testcontainers.ExUnit

  alias Testcontainers.DockerCompose
  alias Testcontainers.Compose.ComposeEnvironment

  @compose_path Path.expand("../docker-compose.yml", __DIR__)

  compose :env, DockerCompose.new(@compose_path), shared: true

  test "can connect to postgres (shared)", %{env: env} do
    assert %ComposeEnvironment{} = env

    host = ComposeEnvironment.get_service_host(env, "postgres")
    port = ComposeEnvironment.get_service_port(env, "postgres", 5432)

    {:ok, pid} =
      Postgrex.start_link(
        hostname: host,
        port: port,
        username: "postgres",
        password: "postgres",
        database: "hello_compose_test"
      )

    assert {:ok, %Postgrex.Result{num_rows: 1}} = Postgrex.query(pid, "SELECT 1", [])
    GenServer.stop(pid)
  end

  test "can connect to redis (shared)", %{env: env} do
    host = ComposeEnvironment.get_service_host(env, "redis")
    port = ComposeEnvironment.get_service_port(env, "redis", 6379)

    {:ok, conn} = :gen_tcp.connect(~c"#{host}", port, [:binary, active: false], 5000)
    :gen_tcp.send(conn, "PING\r\n")
    {:ok, response} = :gen_tcp.recv(conn, 0, 5000)
    assert response =~ "PONG"
    :gen_tcp.close(conn)
  end

  test "shared env has same project name across tests", %{env: env} do
    assert is_binary(env.project_name)
    assert String.starts_with?(env.project_name, "tc-")
  end
end

defmodule Hello.DockerComposePerTestTest do
  use ExUnit.Case, async: false

  import Testcontainers.ExUnit

  alias Testcontainers.DockerCompose
  alias Testcontainers.Compose.ComposeEnvironment

  @compose_path Path.expand("../docker-compose.yml", __DIR__)

  compose :env, DockerCompose.new(@compose_path), shared: false

  test "can connect to postgres (per-test)", %{env: env} do
    assert %ComposeEnvironment{} = env

    host = ComposeEnvironment.get_service_host(env, "postgres")
    port = ComposeEnvironment.get_service_port(env, "postgres", 5432)

    {:ok, pid} =
      Postgrex.start_link(
        hostname: host,
        port: port,
        username: "postgres",
        password: "postgres",
        database: "hello_compose_test"
      )

    assert {:ok, %Postgrex.Result{num_rows: 1}} = Postgrex.query(pid, "SELECT 1", [])
    GenServer.stop(pid)
  end

  test "can connect to redis (per-test)", %{env: env} do
    host = ComposeEnvironment.get_service_host(env, "redis")
    port = ComposeEnvironment.get_service_port(env, "redis", 6379)

    {:ok, conn} = :gen_tcp.connect(~c"#{host}", port, [:binary, active: false], 5000)
    :gen_tcp.send(conn, "PING\r\n")
    {:ok, response} = :gen_tcp.recv(conn, 0, 5000)
    assert response =~ "PONG"
    :gen_tcp.close(conn)
  end
end
