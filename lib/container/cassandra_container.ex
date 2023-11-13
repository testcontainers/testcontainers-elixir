defmodule Testcontainers.CassandraContainer do
  @moduledoc """
  Provides functionality for creating and managing Cassandra container configurations.
  """

  alias Testcontainers.CassandraContainer
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

  def port(%Container{} = container), do: Container.mapped_port(container, @default_port)

  def connection_uri(%Container{} = container) do
    "#{Testcontainers.get_host()}:#{port(container)}"
  end

  defimpl ContainerBuilder do
    import Container

    @doc """
    Implementation of the `ContainerBuilder` protocol for `CephContainer`.

    This implementation provides the logic for building a container configuration specific to Ceph. It ensures the provided image is compatible, sets up necessary environment variables, configures network settings, and applies a waiting strategy to ensure the container is fully operational before it's used.

    The build process raises an `ArgumentError` if the specified container image is not compatible with the expected Ceph image.

    ## Examples

        # Assuming `ContainerBuilder.build/2` is called from somewhere in the application with a `CephContainer` configuration:
        iex> config = CephContainer.new()
        iex> built_container = ContainerBuilder.build(config, [])
        # `built_container` is now a ready-to-use `%Container{}` configured specifically for Ceph.

    ## Errors

    - Raises `ArgumentError` if the provided image is not compatible with the default Ceph image.
    """
    @spec build(%CassandraContainer{}) :: %Container{}
    @impl true
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
    end
  end
end
