defmodule Testcontainers.Connection.DockerHostStrategy.DockerHostFromEnvTest do
  use ExUnit.Case, async: true

  alias Testcontainers.Connection.DockerHostStrategyEvaluator
  alias Testcontainers.Connection.DockerHostStrategy.DockerHostFromEnv

  describe "DockerHostFromEnv" do
    setup do
      System.put_env("X_DOCKER_HOST", "tcp://somehostname:9876")
    end

    test "should return ok if env exists" do
      strategy = %DockerHostFromEnv{key: "X_DOCKER_HOST"}

      {:ok, "tcp://somehostname:9876"} =
        DockerHostStrategyEvaluator.run_strategies([strategy], [])
    end

    test "should return error if env does not exist" do
      strategy = %DockerHostFromEnv{key: "NOT_SET"}

      {:error, docker_host_from_env: :docker_host_not_found} =
        DockerHostStrategyEvaluator.run_strategies([strategy], [])
    end
  end
end
