defmodule Hello.DockerComposeTest do
  use ExUnit.Case, async: false

  alias Testcontainers.DockerCompose
  alias Testcontainers.Compose.ComposeEnvironment

  @compose_path Path.expand("../docker-compose.yml", __DIR__)

  describe "docker compose with phoenix" do
    setup do
      compose = DockerCompose.new(@compose_path)

      {:ok, env} = Testcontainers.start_compose(compose)

      on_exit(fn -> Testcontainers.stop_compose(env) end)

      %{env: env}
    end

    test "starts postgres and can connect to it", %{env: env} do
      assert %ComposeEnvironment{} = env

      host = ComposeEnvironment.get_service_host(env, "postgres")
      port = ComposeEnvironment.get_service_port(env, "postgres", 5432)

      assert is_binary(host)
      assert is_integer(port)
      assert port > 0

      # Verify service metadata
      service = ComposeEnvironment.get_service(env, "postgres")
      assert service.service_name == "postgres"
      assert service.state == "running"

      # Verify we can connect to postgres
      {:ok, pid} =
        Postgrex.start_link(
          hostname: host,
          port: port,
          username: "postgres",
          password: "postgres",
          database: "hello_compose_test"
        )

      assert {:ok, %Postgrex.Result{num_rows: 1}} =
               Postgrex.query(pid, "SELECT 1", [])

      GenServer.stop(pid)
    end
  end
end
