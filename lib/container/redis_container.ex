# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule Testcontainers.RedisContainer do
  @moduledoc """
  Provides functionality for creating and managing Redis container configurations.
  """

  alias Testcontainers.ContainerBuilder
  alias Testcontainers.Container
  alias Testcontainers.CommandWaitStrategy
  alias Testcontainers.RedisContainer

  import Testcontainers.Container, only: [is_valid_image: 1]

  @default_image "redis"
  @default_tag "7.2-alpine"
  @default_image_with_tag "#{@default_image}:#{@default_tag}"
  @default_port 6379
  @default_wait_timeout 60_000

  @enforce_keys [:image, :port, :wait_timeout]
  defstruct [
    :image,
    :port,
    :wait_timeout,
    check_image: @default_image,
    reuse: false
  ]

  @doc """
  Creates a new `RedisContainer` struct with default configurations.
  """
  def new,
    do: %__MODULE__{
      image: @default_image_with_tag,
      wait_timeout: @default_wait_timeout,
      port: @default_port
    }

  @doc """
  Overrides the default image used for the Redis container.

  ## Examples

      iex> config = RedisContainer.new()
      iex> new_config = RedisContainer.with_image(config, "redis:xyz")
      iex> new_config.image
      "redis:xyz"
  """
  def with_image(%__MODULE__{} = config, image) when is_binary(image) do
    %{config | image: image}
  end

  @doc """
  Overrides the default port used for the Redis container.

  Note: this will not change what port the docker container is listening to internally.

  ## Examples

      iex> config = RedisContainer.new()
      iex> new_config = RedisContainer.with_port(config, 1111)
      iex> new_config.port
      1111
  """
  def with_port(%__MODULE__{} = config, port) when is_integer(port) do
    %{config | port: port}
  end

  @doc """
  Overrides the default wait timeout used for the Redis container.

  Note: this timeout will be used for each individual wait strategy.

  ## Examples

      iex> config = RedisContainer.new()
      iex> new_config = RedisContainer.with_wait_timeout(config, 8000)
      iex> new_config.wait_timeout
      8000
  """
  def with_wait_timeout(%__MODULE__{} = config, wait_timeout) when is_integer(wait_timeout) do
    %{config | wait_timeout: wait_timeout}
  end

  @doc """
  Set the regular expression to check the image validity.
  """
  def with_check_image(%__MODULE__{} = config, check_image) when is_valid_image(check_image) do
    %__MODULE__{config | check_image: check_image}
  end

  @doc """
  Set the reuse flag to reuse the container if it is already running.
  """
  def with_reuse(%__MODULE__{} = config, reuse) when is_boolean(reuse) do
    %__MODULE__{config | reuse: reuse}
  end

  @doc """
  Retrieves the default Docker image for the Redis container.
  """
  def default_image, do: @default_image

  @doc """
  Returns the port on the _host machine_ where the Redis container is listening.
  """
  def port(%Container{} = container), do: Container.mapped_port(container, @default_port)

  @doc """
  Generates the connection URL for accessing the Redis service running within the container.

  This URL is based on the standard localhost IP and the mapped port for the container.

  ## Parameters

  - `container`: The active Redis container instance in the form of a %Container{} struct.

  ## Examples

      iex> RedisContainer.connection_url(container)
      "http://localhost:32768" # This value will be different depending on the mapped port.
  """
  def connection_url(%Container{} = container),
    do: "redis://#{Testcontainers.get_host()}:#{port(container)}/"

  defimpl ContainerBuilder do
    import Container

    @doc """
    Implementation of the `ContainerBuilder` protocol specific to `RedisContainer`.

    This function builds a new container configuration, ensuring the Redis image is compatible, setting environment variables, and applying a waiting strategy for the container to be ready.

    The build process raises an `ArgumentError` if the specified container image is not compatible with the expected Redis image.

    ## Examples

        # Assuming `ContainerBuilder.build/2` is called from somewhere in the application with a `RedisContainer` configuration:
        iex> config = RedisContainer.new()
        iex> built_container = ContainerBuilder.build(config, [])
        # `built_container` is now a ready-to-use `%Container{}` configured specifically for Redis.

    ## Errors

    - Raises `ArgumentError` if the provided image is not compatible with the default Redis image.
    """
    @spec build(%RedisContainer{}) :: %Container{}
    @impl true
    def build(%RedisContainer{} = config) do
      new(config.image)
      |> with_exposed_port(config.port)
      |> with_waiting_strategy(
        CommandWaitStrategy.new(["redis-cli", "PING"], config.wait_timeout)
      )
      |> with_check_image(config.check_image)
      |> with_reuse(config.reuse)
      |> valid_image!()
    end

    @impl true
    @spec after_start(%RedisContainer{}, %Container{}, %Tesla.Env{}) :: :ok
    def after_start(_config, _container, _conn), do: :ok
  end
end

defmodule Testcontainers.Container.RedisContainer do
  @moduledoc """
  Deprecated. Use `Testcontainers.RedisContainer` instead.

  This module is kept for backward compatibility and will be removed in future releases.
  """

  @deprecated "Use Testcontainers.RedisContainer instead"

  defdelegate new, to: Testcontainers.RedisContainer
  defdelegate with_image(self, image), to: Testcontainers.RedisContainer
  defdelegate with_port(self, port), to: Testcontainers.RedisContainer
  defdelegate with_wait_timeout(self, wait_timeout), to: Testcontainers.RedisContainer
  defdelegate port(self), to: Testcontainers.RedisContainer
  defdelegate connection_url(self), to: Testcontainers.RedisContainer
end
