defmodule Testcontainers.Compose.ComposeIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias Testcontainers.DockerCompose
  alias Testcontainers.Compose.ComposeEnvironment

  @fixtures_path Path.expand("../fixtures", __DIR__)

  describe "full compose lifecycle" do
    test "starts and stops a compose environment with redis" do
      compose = DockerCompose.new(@fixtures_path)

      {:ok, env} = Testcontainers.start_compose(compose)

      assert %ComposeEnvironment{} = env
      assert is_binary(env.project_name)
      assert String.starts_with?(env.project_name, "tc-")
      assert is_binary(env.docker_host)

      # Verify redis service is present
      redis_service = ComposeEnvironment.get_service(env, "redis")
      assert redis_service != nil
      assert redis_service.service_name == "redis"
      assert redis_service.state == "running"

      # Verify port mapping
      host = ComposeEnvironment.get_service_host(env, "redis")
      port = ComposeEnvironment.get_service_port(env, "redis", 6379)

      assert is_binary(host)
      assert is_integer(port)
      assert port > 0

      # Verify connectivity to redis
      {:ok, conn} = :gen_tcp.connect(~c"#{host}", port, [:binary, active: false], 5000)
      :gen_tcp.send(conn, "PING\r\n")
      {:ok, response} = :gen_tcp.recv(conn, 0, 5000)
      assert response =~ "PONG"
      :gen_tcp.close(conn)

      # Stop the compose environment
      assert :ok = Testcontainers.stop_compose(env)
    end
  end
end
