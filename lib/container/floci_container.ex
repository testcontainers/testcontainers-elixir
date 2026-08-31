defmodule Testcontainers.FlociContainer do
  @moduledoc """
  Provides functionality for creating and managing Floci container configurations.

  Floci is a local AWS emulator. All emulated services are available through a
  single endpoint returned by `connection_url/1`.

  Docker assigns the endpoint's host port after the container is created, so it
  cannot be injected into Floci before startup. If a test follows absolute URLs
  returned by Floci, configure `with_base_url/2` with an address reachable in
  that test's fixed-port or shared-network topology.
  """

  alias Testcontainers.Container
  alias Testcontainers.ContainerBuilder
  alias Testcontainers.FlociContainer
  alias Testcontainers.LogWaitStrategy

  import Testcontainers.Container, only: [is_valid_image: 1]

  @default_image "floci/floci"
  @default_tag "1.7.0"
  @default_image_with_tag "#{@default_image}:#{@default_tag}"
  @default_region "us-east-1"
  @default_availability_zone "us-east-1a"
  @default_account_id "000000000000"
  @default_access_key "test"
  @default_secret_key "test"
  @default_port 4566
  @default_wait_timeout 60_000

  @type t :: %__MODULE__{}

  @enforce_keys [
    :image,
    :region,
    :availability_zone,
    :account_id,
    :access_key,
    :secret_key,
    :wait_timeout
  ]
  defstruct [
    :image,
    :region,
    :availability_zone,
    :account_id,
    :access_key,
    :secret_key,
    :wait_timeout,
    base_url: nil,
    check_image: @default_image,
    reuse: false
  ]

  @doc """
  Creates a new Floci container configuration with default settings.
  """
  def new,
    do: %__MODULE__{
      image: @default_image_with_tag,
      region: @default_region,
      availability_zone: @default_availability_zone,
      account_id: @default_account_id,
      access_key: @default_access_key,
      secret_key: @default_secret_key,
      wait_timeout: @default_wait_timeout
    }

  @doc """
  Overrides the Docker image used for the Floci container.
  """
  def with_image(%__MODULE__{} = config, image) when is_binary(image) do
    %__MODULE__{config | image: image}
  end

  @doc """
  Sets the default AWS region advertised by Floci.
  """
  def with_region(%__MODULE__{} = config, region) when is_binary(region) do
    %__MODULE__{config | region: region}
  end

  @doc """
  Sets the default AWS availability zone advertised by Floci.
  """
  def with_availability_zone(%__MODULE__{} = config, availability_zone)
      when is_binary(availability_zone) do
    %__MODULE__{config | availability_zone: availability_zone}
  end

  @doc """
  Sets the default AWS account ID advertised by Floci.
  """
  def with_account_id(%__MODULE__{} = config, account_id) when is_binary(account_id) do
    %__MODULE__{config | account_id: account_id}
  end

  @doc """
  Sets the base URL Floci embeds in generated absolute URLs.

  This is useful for APIs such as SQS that return URLs in their responses. The
  URL must be reachable by the test client, typically through a fixed host port
  or a shared Docker network. For ordinary AWS SDK requests, use the dynamic
  endpoint returned by `connection_url/1` instead.
  """
  def with_base_url(%__MODULE__{} = config, base_url) when is_binary(base_url) do
    %__MODULE__{config | base_url: base_url}
  end

  @doc """
  Sets the dummy AWS access key returned by `connection_opts/1`.
  """
  def with_access_key(%__MODULE__{} = config, access_key) when is_binary(access_key) do
    %__MODULE__{config | access_key: access_key}
  end

  @doc """
  Sets the dummy AWS secret key returned by `connection_opts/1`.
  """
  def with_secret_key(%__MODULE__{} = config, secret_key) when is_binary(secret_key) do
    %__MODULE__{config | secret_key: secret_key}
  end

  @doc """
  Overrides the maximum time to wait for Floci to become ready.
  """
  def with_wait_timeout(%__MODULE__{} = config, wait_timeout) when is_integer(wait_timeout) do
    %__MODULE__{config | wait_timeout: wait_timeout}
  end

  @doc """
  Sets the regular expression used to validate the configured image.
  """
  def with_check_image(%__MODULE__{} = config, check_image) when is_valid_image(check_image) do
    %__MODULE__{config | check_image: check_image}
  end

  @doc """
  Sets whether the container should be reused when reuse is enabled globally.
  """
  def with_reuse(%__MODULE__{} = config, reuse) when is_boolean(reuse) do
    %__MODULE__{config | reuse: reuse}
  end

  def default_image, do: @default_image
  def default_region, do: @default_region
  def default_availability_zone, do: @default_availability_zone
  def default_account_id, do: @default_account_id
  def default_access_key, do: @default_access_key
  def default_secret_key, do: @default_secret_key
  def default_port, do: @default_port

  @doc """
  Returns the port on the Docker host where Floci is listening.
  """
  def port(%Container{} = container), do: Testcontainers.get_port(container, @default_port)

  @doc """
  Returns the endpoint URL to use with AWS SDK clients.
  """
  def connection_url(%Container{} = container) do
    "http://#{Testcontainers.get_host(container)}:#{port(container)}"
  end

  @doc """
  Returns connection options compatible with `ExAws.request/2`.
  """
  def connection_opts(%Container{} = container) do
    [
      port: FlociContainer.port(container),
      scheme: "http://",
      host: Testcontainers.get_host(container),
      region: container.environment[:FLOCI_DEFAULT_REGION],
      access_key_id: container.environment[:AWS_ACCESS_KEY_ID],
      secret_access_key: container.environment[:AWS_SECRET_ACCESS_KEY]
    ]
  end

  defimpl ContainerBuilder do
    import Container

    @spec build(FlociContainer.t()) :: Container.t()
    @impl true
    def build(%FlociContainer{} = config) do
      new(config.image)
      |> with_exposed_port(FlociContainer.default_port())
      |> with_environment(:FLOCI_DEFAULT_REGION, config.region)
      |> with_environment(:FLOCI_DEFAULT_AVAILABILITY_ZONE, config.availability_zone)
      |> with_environment(:FLOCI_DEFAULT_ACCOUNT_ID, config.account_id)
      |> with_environment(:AWS_ACCESS_KEY_ID, config.access_key)
      |> with_environment(:AWS_SECRET_ACCESS_KEY, config.secret_key)
      |> then(fn container ->
        if config.base_url do
          with_environment(container, :FLOCI_BASE_URL, config.base_url)
        else
          container
        end
      end)
      |> with_check_image(config.check_image)
      |> with_reuse(config.reuse)
      |> with_waiting_strategy(
        # Floci exposes its init endpoint before ready hooks have completed. The
        # readiness log is emitted only after all configured ready hooks finish.
        LogWaitStrategy.new(~r/.*Ready\..*/, config.wait_timeout)
      )
      |> valid_image!()
    end

    @impl true
    def after_start(_config, _container, _conn), do: :ok
  end
end
