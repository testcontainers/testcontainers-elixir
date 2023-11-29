defmodule Testcontainers.ZookeeperContainer do
  @moduledoc """
  Provides functionality for creating and managing Zookeeper container configurations.
  """
  alias Testcontainers.Container
  alias Testcontainers.ZookeeperContainer
  alias Testcontainers.CommandWaitStrategy

  @default_image "bitnami/zookeeper"
  @default_image_with_tag "#{@default_image}:3.7.2"
  @default_port 2181
  @default_wait_timeout 60_000

  @enforce_keys [:image, :port, :wait_timeout]
  defstruct [:image, :port, :wait_timeout]

  @doc """
  Creates a new `ZookeeperContainer` struct with default configurations.
  """
  def new do
    %__MODULE__{
      image: @default_image_with_tag,
      port: @default_port,
      wait_timeout: @default_wait_timeout
    }
  end

  @doc """
  Overrides the default image used for the Zookeeper container.
  """
  def with_image(config, image) when is_binary(image) do
    %{config | image: image}
  end

  @doc """
  Overrides the default port used for the Zookeeper container.
  """
  def with_port(config, port) when is_integer(port) do
    %{config | port: port}
  end

  @doc """
  Overrides the default timeout used for the Zookeeper container.
  """
  def with_wait_timeout(config, timeout) when is_integer(timeout) do
    %{config | wait_timeout: timeout}
  end

  defimpl Testcontainers.ContainerBuilder do
    import Container

    @impl true
    @spec build(%ZookeeperContainer{}) :: %Container{}
    def build(%ZookeeperContainer{} = config) do
      new(config.image)
      |> with_fixed_port(config.port)
      |> with_environment(:ALLOW_ANONYMOUS_LOGIN, "true")
      |> with_waiting_strategy(
        CommandWaitStrategy.new(
          ["echo", "srvr", "|", "nc", "localhost", "2181", "|", "grep", "Mode"],
          config.wait_timeout,
          1000
        )
      )
    end
  end
end
