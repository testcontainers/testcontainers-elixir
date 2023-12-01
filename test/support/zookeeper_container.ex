defmodule Test.ZookeeperContainer do
  @moduledoc """
  Provides functionality for creating base Zookeeper container configurations to act
  as a external Zookeeper cluster for other containers.
  This is useful for testing Kafka containers.
  """
  defstruct []

  defimpl Testcontainers.ContainerBuilder do
    alias Testcontainers.CommandWaitStrategy
    import Testcontainers.Container

    @impl true
    def build(%Test.ZookeeperContainer{}) do
      new("bitnami/zookeeper:3.7.2")
      |> with_fixed_port(2181)
      |> with_environment(:ALLOW_ANONYMOUS_LOGIN, "true")
      |> with_waiting_strategy(
        CommandWaitStrategy.new(
          ["echo", "srvr", "|", "nc", "localhost", "2181", "|", "grep", "Mode"],
          15_000,
          1000
        )
      )
    end

    @impl true
    def is_starting(_config, _container, _conn), do: :ok
  end
end
