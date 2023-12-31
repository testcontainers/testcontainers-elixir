defmodule Testcontainers.Connection.DockerHostStrategy.DockerSocketPathTest do
  use ExUnit.Case, async: true

  alias Testcontainers.DockerHostStrategyEvaluator
  alias Testcontainers.DockerSocketPathStrategy

  describe "DockerSocketPathStrategy" do
    test "should return :enoent if docker socket exists but is not a real socket" do
      strategy = %DockerSocketPathStrategy{socket_paths: ["test/fixtures/docker.sock"]}

      {:error, docker_socket_path: :enoent} =
        DockerHostStrategyEvaluator.run_strategies([strategy], [])
    end

    test "should return error if docker socket does not exist" do
      strategy = %DockerSocketPathStrategy{socket_paths: ["/does/not/exist/at/all"]}

      {:error, docker_socket_path: :docker_socket_not_found} =
        DockerHostStrategyEvaluator.run_strategies([strategy], [])
    end
  end
end
