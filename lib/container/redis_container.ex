# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule Testcontainers.Container.RedisContainer do
  @moduledoc """
  Functions to build and interact with Redis containers.
  """

  alias Testcontainers.Container
  alias Testcontainers.WaitStrategy.CommandWaitStrategy

  @redis_port 6379
  @wait_strategy CommandWaitStrategy.new(["redis-cli", "PING"])

  @doc """
  Creates a Redis container.

  Runs Redis 6.0 by default, but a custom image can also be set.
  """
  def new(image \\ "redis:6.0-alpine", _opts \\ []) do
    Container.new(
      image,
      exposed_ports: [@redis_port],
      environment: %{}
    )
    |> Container.with_waiting_strategy(@wait_strategy)
  end

  @doc """
  Returns the port on the _host machine_ where the Redis container is listening.
  """
  def port(%Container{} = container), do: Container.mapped_port(container, @redis_port)

  @doc """
  Returns the connection url to connect to Redis from the _host machine_.
  """
  def connection_url(%Container{} = container), do: "redis://localhost:#{port(container)}/"
end
