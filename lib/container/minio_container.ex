defmodule Testcontainers.MinioContainer do
  alias Testcontainers.Container
  alias Testcontainers.MinioContainer
  alias Testcontainers.ContainerBuilder
  alias Testcontainers.LogWaitStrategy

  @default_image "minio/minio"
  @default_tag "RELEASE.2023-11-11T08-14-41Z"
  @default_image_with_tag "#{@default_image}:#{@default_tag}"
  @default_bucket "test"
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

  def default_ui_port, do: @default_ui_port
  def default_s3_port, do: @default_s3_port

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
  end
end
