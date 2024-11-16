defmodule Testcontainers.Connection.DockerHostStrategy.DockerHostFromEnvTest do
  use ExUnit.Case, async: true

  alias Testcontainers.DockerHostStrategyEvaluator
  alias Testcontainers.DockerHostFromEnvStrategy

  describe "DockerHostFromEnvStrategy" do
    setup do
      System.put_env("X_DOCKER_HOST", "tcp://localhost:9999")
    end

    test "should return :econnrefused if env exists with a proper url" do
      strategy = %DockerHostFromEnvStrategy{key: "X_DOCKER_HOST"}

      {:error,
       "Failed to find docker host: [docker_host_from_env: {:econnrefused, \"X_DOCKER_HOST\"}]"} =
        DockerHostStrategyEvaluator.run_strategies([strategy], [])
    end

    test "should return error if env is not set to a proper url" do
      strategy = %DockerHostFromEnvStrategy{key: "NOT_SET"}

      {:error,
       "Failed to find docker host: [docker_host_from_env: {:docker_host_not_found, \"NOT_SET\"}]"} =
        DockerHostStrategyEvaluator.run_strategies([strategy], [])
    end
  end
end
