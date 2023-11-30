# SPDX-License-Identifier: MIT
defmodule Testcontainers.CassandraContainer do
  @moduledoc """
  Provides functionality for creating and managing Cassandra container configurations.
  """

  alias Testcontainers.CassandraContainer
  alias Testcontainers.LogWaitStrategy
  alias Testcontainers.ContainerBuilder
  alias Testcontainers.Container

  @default_image "cassandra"
  @default_tag "3.11.2"
  @default_image_with_tag "#{@default_image}:#{@default_tag}"
  @default_username "cassandra"
  @default_password "cassandra"
  @default_port 9042
  @default_wait_timeout 60_000

  @enforce_keys [:image, :wait_timeout]
  defstruct [:image, :wait_timeout]

  def new,
    do: %__MODULE__{
      image: @default_image_with_tag,
      wait_timeout: @default_wait_timeout
    }

  def with_image(%__MODULE__{} = config, image) when is_binary(image) do
    %{config | image: image}
  end

  def default_image, do: @default_image

  def default_port, do: @default_port

  def get_username, do: @default_username

  def get_password, do: @default_password

  @doc """
  Retrieves the port mapped by the Docker host for the Cassandra container.
  """
  def port(%Container{} = container), do: Container.mapped_port(container, @default_port)

  @doc """
  Generates the connection URL for accessing the Cassandra service running within the container.
  """
  def connection_uri(%Container{} = container) do
    "#{Testcontainers.get_host()}:#{port(container)}"
  end

  defimpl ContainerBuilder do
    import Container

    @impl true
    @spec build(%CassandraContainer{}) :: %Container{}
    def build(%CassandraContainer{} = config) do
      if not String.starts_with?(config.image, CassandraContainer.default_image()) do
        raise ArgumentError,
          message:
            "Image #{config.image} is not compatible with #{CassandraContainer.default_image()}"
      end

      new(config.image)
      |> with_exposed_port(CassandraContainer.default_port())
      |> with_environment(:CASSANDRA_SNITCH, "GossipingPropertyFileSnitch")
      |> with_environment(
        :JVM_OPTS,
        "-Dcassandra.skip_wait_for_gossip_to_settle=0 -Dcassandra.initial_token=0"
      )
      |> with_environment(:HEAP_NEWSIZE, "128M")
      |> with_environment(:MAX_HEAP_SIZE, "1024M")
      |> with_environment(:CASSANDRA_ENDPOINT_SNITCH, "GossipingPropertyFileSnitch")
      |> with_environment(:CASSANDRA_DC, "datacenter1")
      |> with_waiting_strategy(
        LogWaitStrategy.new(
          ~r/Starting listening for CQL clients on \/0\.0\.0\.0:#{CassandraContainer.default_port()}.*/,
          config.wait_timeout
        )
      )
    end

    @impl true
    @spec is_starting(%CassandraContainer{}, %Container{}, %Tesla.Env{}) :: :ok
    def is_starting(_config, _container, _conn), do: :ok
  end
end
