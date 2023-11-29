defmodule Testcontainers.MinioContainer do
  @moduledoc """
  Provides functionality for creating and managing Minio container configurations.
  """

  alias Testcontainers.Container
  alias Testcontainers.MinioContainer
  alias Testcontainers.ContainerBuilder
  alias Testcontainers.LogWaitStrategy

  @default_image "minio/minio"
  @default_tag "RELEASE.2023-11-11T08-14-41Z"
  @default_image_with_tag "#{@default_image}:#{@default_tag}"
  @default_username "minioadmin"
  @default_password "minioadmin"
  @default_s3_port 9000
  @default_ui_port 9001
  @default_wait_timeout 60_000

  @enforce_keys [:image, :username, :password, :wait_timeout]
  defstruct [:image, :username, :password, :wait_timeout]

  def new,
    do: %__MODULE__{
      image: @default_image_with_tag,
      username: @default_username,
      password: @default_password,
      wait_timeout: @default_wait_timeout
    }

  def get_username, do: @default_username
  def get_password, do: @default_password
  def default_ui_port, do: @default_ui_port
  def default_s3_port, do: @default_s3_port

  @doc """
  Retrieves the port mapped by the Docker host for the Minio container.
  """
  def port(%Container{} = container), do: Container.mapped_port(container, @default_s3_port)

  @doc """
  Generates the connection URL for accessing the Minio service running within the container.
  """
  def connection_url(%Container{} = container) do
    "http://#{Testcontainers.get_host()}:#{port(container)}"
  end

  @doc """
  Generates the connection options for accessing the Minio service running within the container.
  Compatible with what ex_aws expects in `ExAws.request(options)`
  """
  def connection_opts(%Container{} = container) do
    [
      port: MinioContainer.port(container),
      scheme: "http://",
      host: Testcontainers.get_host(),
      access_key_id: container.environment[:MINIO_ROOT_USER],
      secret_access_key: container.environment[:MINIO_ROOT_PASSWORD]
    ]
  end

  defimpl ContainerBuilder do
    import Container

    @spec build(%MinioContainer{}) :: %Container{}
    @impl true
    def build(%MinioContainer{} = config) do
      new(config.image)
      |> with_exposed_ports([MinioContainer.default_s3_port(), MinioContainer.default_ui_port()])
      |> with_environment(:MINIO_ROOT_USER, config.username)
      |> with_environment(:MINIO_ROOT_PASSWORD, config.password)
      |> with_cmd(["server", "--console-address", ":#{MinioContainer.default_ui_port()}", "/data"])
      |> with_waiting_strategy(
        LogWaitStrategy.new(~r/.*Status:         1 Online, 0 Offline..*/, config.wait_timeout)
      )
    end

    @impl true
    @spec is_starting(%MinioContainer{}, %Container{}) :: any()
    def is_starting(_config, _container), do: nil
  end
end
