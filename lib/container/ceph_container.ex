# SPDX-License-Identifier: MIT
defmodule Testcontainers.CephContainer do
  @moduledoc """
  Provides functionality for creating and managing Ceph container configurations.
  """

  alias Testcontainers.LogWaitStrategy
  alias Testcontainers.CephContainer
  alias Testcontainers.ContainerBuilder
  alias Testcontainers.Container

  import Testcontainers.Container, only: [is_valid_image: 1]

  @default_image "quay.io/ceph/demo"
  @default_tag "latest-quincy"
  @default_image_with_tag "#{@default_image}:#{@default_tag}"
  @default_bucket "test"
  @default_access_key "test"
  @default_secret_key UUID.uuid4()
  @default_port 8080
  @default_wait_timeout 300_000

  @enforce_keys [:image, :access_key, :secret_key, :bucket, :port, :wait_timeout]
  defstruct [
    :image,
    :access_key,
    :secret_key,
    :bucket,
    :port,
    :wait_timeout,
    check_image: @default_image,
    reuse: false
  ]

  @doc """
  Creates a new `CephContainer` struct with default attributes.
  """
  def new,
    do: %__MODULE__{
      image: @default_image_with_tag,
      wait_timeout: @default_wait_timeout,
      port: @default_port,
      access_key: @default_access_key,
      secret_key: @default_secret_key,
      bucket: @default_bucket
    }

  @doc """
  Sets the `image` of the Ceph container configuration.

  ## Examples

      iex> config = CephContainer.new()
      iex> new_config = CephContainer.with_image(config, "quay.io/ceph/alternative")
      iex> new_config.image
      "quay.io/ceph/alternative"
  """
  def with_image(%__MODULE__{} = config, image) when is_binary(image) do
    %{config | image: image}
  end

  @doc """
  Sets the `access_key` used for authentication with the Ceph container.

  ## Examples

      iex> config = CephContainer.new()
      iex> new_config = CephContainer.with_access_key(config, "new_access_key")
      iex> new_config.access_key
      "new_access_key"
  """
  def with_access_key(%__MODULE__{} = config, access_key) when is_binary(access_key) do
    %{config | access_key: access_key}
  end

  @doc """
  Sets the `secret_key` used for authentication with the Ceph container.

  ## Examples

      iex> config = CephContainer.new()
      iex> new_config = CephContainer.with_secret_key(config, "new_secret_key")
      iex> new_config.secret_key
      "new_secret_key"
  """
  def with_secret_key(%__MODULE__{} = config, secret_key) when is_binary(secret_key) do
    %{config | secret_key: secret_key}
  end

  @doc """
  Sets the `bucket` that is automatically in the Ceph container.

  ## Examples

      iex> config = CephContainer.new()
      iex> new_config = CephContainer.with_bucket(config, "test_bucket")
      iex> new_config.bucket
      "test_bucket"
  """
  def with_bucket(%__MODULE__{} = config, bucket) when is_binary(bucket) do
    %{config | bucket: bucket}
  end

  @doc """
  Sets the port on which the Ceph container will be exposed.

  ## Parameters

  - `config`: The current Ceph container configuration.
  - `port`: The target port number.

  ## Examples

      iex> config = CephContainer.new()
      iex> new_config = CephContainer.with_port(config, 8081)
      iex> new_config.port
      8081
  """
  def with_port(%__MODULE__{} = config, port) when is_integer(port) do
    %{config | port: port}
  end

  @doc """
  Sets the maximum time (in milliseconds) the system will wait for the Ceph container to be ready before timing out.

  ## Parameters

  - `config`: The current Ceph container configuration.
  - `wait_timeout`: The time to wait in milliseconds.

  ## Examples

      iex> config = CephContainer.new()
      iex> new_config = CephContainer.with_wait_timeout(config, 400_000)
      iex> new_config.wait_timeout
      400_000
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
  Retrieves the default Docker image used for the Ceph container.

  ## Examples

      iex> CephContainer.default_image()
      "quay.io/ceph/demo"
  """
  def default_image, do: @default_image

  @doc """
  Retrieves the port mapped by the Docker host for the Ceph container.

  ## Parameters

  - `container`: The active Ceph container instance.

  ## Examples

      iex> CephContainer.port(container)
      32768 # This value will be different depending on the mapped port.
  """
  def port(%Container{} = container), do: Container.mapped_port(container, @default_port)

  @doc """
  Generates the connection URL for accessing the Ceph service running within the container.

  This URL is based on the standard localhost IP and the mapped port for the container.

  ## Parameters

  - `container`: The active Ceph container instance.

  ## Examples

      iex> CephContainer.connection_url(container)
      "http://localhost:32768" # This value will be different depending on the mapped port.
  """
  def connection_url(%Container{} = container) do
    "http://#{Testcontainers.get_host()}:#{port(container)}"
  end

  @doc """
  Generates the connection options for accessing the Ceph service running within the container.
  Compatible with what ex_aws expects in `ExAws.request(options)`
  """
  def connection_opts(%Container{} = container) do
    [
      port: CephContainer.port(container),
      scheme: "http://",
      host: Testcontainers.get_host(),
      access_key_id: container.environment[:CEPH_DEMO_ACCESS_KEY],
      secret_access_key: container.environment[:CEPH_DEMO_SECRET_KEY]
    ]
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
    @spec build(%CephContainer{}) :: %Container{}
    @impl true
    def build(%CephContainer{} = config) do
      new(config.image)
      |> with_exposed_port(config.port)
      |> with_environment(:CEPH_DEMO_UID, "demo")
      |> with_environment(:CEPH_DEMO_BUCKET, config.bucket)
      |> with_environment(:CEPH_DEMO_ACCESS_KEY, config.access_key)
      |> with_environment(:CEPH_DEMO_SECRET_KEY, config.secret_key)
      |> with_environment(:CEPH_PUBLIC_NETWORK, "0.0.0.0/0")
      |> with_environment(:MON_IP, "127.0.0.1")
      |> with_environment(:RGW_NAME, "localhost")
      |> with_waiting_strategy(
        LogWaitStrategy.new(
          ~r/.*Bucket 's3:\/\/#{config.bucket}\/' created.*/,
          config.wait_timeout,
          5000
        )
      )
      |> with_check_image(config.check_image)
      |> with_reuse(config.reuse)
      |> valid_image!()
    end

    @impl true
    @spec after_start(%CephContainer{}, %Container{}, %Tesla.Env{}) :: :ok
    def after_start(_config, _container, _conn), do: :ok
  end
end
