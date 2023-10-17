defmodule Testcontainers.Connection.DockerHostStrategy.DockerSocketPathTest do
  use ExUnit.Case, async: true

  alias Testcontainers.Connection.DockerHostStrategyEvaluator
  alias Testcontainers.Connection.DockerHostStrategy.DockerSocketPath

  describe "DockerSocketPath" do
    test "should return ok if docker socket exists" do
      strategy = %DockerSocketPath{socket_paths: ["test/fixtures/docker.sock"]}

      {:ok, "unix://test/fixtures/docker.sock"} =
        DockerHostStrategyEvaluator.run_strategies([strategy], [])
    end

    test "should return error if docker socket does not exist" do
      strategy = %DockerSocketPath{socket_paths: ["/does/not/exist/at/all"]}

      {:error, docker_socket_path: :docker_socket_not_found} =
        DockerHostStrategyEvaluator.run_strategies([strategy], [])
    end
  end
end
