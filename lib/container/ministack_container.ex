defmodule Testcontainers.MinistackContainer do
  @moduledoc """
  Provides functionality for creating and managing Ministack container configurations.
  """

  alias Testcontainers.Container
  alias Testcontainers.ContainerBuilder
  alias Testcontainers.LogWaitStrategy
  alias Testcontainers.MinistackContainer

  @default_image "ministackorg/ministack"
  @default_tag "1.3.42"
  @default_image_with_tag "#{@default_image}:#{@default_tag}"
  @default_username "111111111111"
  @default_password "anything"
  @default_s3_port 4566
  @default_ui_port 2222
  @default_wait_timeout 60_000

  @type t :: %__MODULE__{}

  @enforce_keys [:image, :username, :password, :wait_timeout]
  defstruct [
    :image,
    :username,
    :password,
    :wait_timeout,
    reuse: false
  ]

  def new,
    do: %__MODULE__{
      image: @default_image_with_tag,
      username: @default_username,
      password: @default_password,
      wait_timeout: @default_wait_timeout
    }

  @doc """
  Set the reuse flag to reuse the container if it is already running.
  """
  def with_reuse(%__MODULE__{} = config, reuse) when is_boolean(reuse) do
    %__MODULE__{config | reuse: reuse}
  end

  def get_username, do: @default_username
  def get_password, do: @default_password
  def default_ui_port, do: @default_ui_port
  def default_s3_port, do: @default_s3_port

  @doc """
  Retrieves the port mapped by the Docker host for the Ministack container.
  """
  def port(%Container{} = container), do: Testcontainers.get_port(container, @default_s3_port)

  @doc """
  Generates the connection URL for accessing the Ministack service running within the container.
  """
  def connection_url(%Container{} = container) do
    "http://#{Testcontainers.get_host(container)}:#{port(container)}"
  end

  @doc """
  Generates the connection options for accessing the Ministack service running within the container.
  Compatible with what ex_aws expects in `ExAws.request(options)`
  """
  def connection_opts(%Container{} = container) do
    [
      port: MinistackContainer.port(container),
      scheme: "http://",
      host: Testcontainers.get_host(container),
      access_key_id: container.environment[:AWS_ACCESS_KEY_ID],
      secret_access_key: container.environment[:AWS_SECRET_ACCESS_KEY]
    ]
  end

  defimpl ContainerBuilder do
    import Container

    @spec build(MinistackContainer.t()) :: Container.t()
    @impl true
    def build(%MinistackContainer{} = config) do
      new(config.image)
      |> with_exposed_ports([
        MinistackContainer.default_s3_port(),
        MinistackContainer.default_ui_port()
      ])
      |> with_environment(:AWS_ACCESS_KEY_ID, config.username)
      |> with_environment(:AWS_SECRET_ACCESS_KEY, config.password)
      |> with_reuse(config.reuse)
      |> with_waiting_strategy(
        LogWaitStrategy.new(
          ~r/.*Ready .* services available on port #{MinistackContainer.default_s3_port()}\./,
          config.wait_timeout,
          1000
        )
      )
    end

    @impl true
    def after_start(_config, _container, _conn), do: :ok
  end
end
