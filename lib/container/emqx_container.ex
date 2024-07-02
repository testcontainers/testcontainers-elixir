defmodule Testcontainers.EmqxContainer do
  @moduledoc """
  Provides functionality for creating and managing EMQX container configurations.
  """

  alias Testcontainers.ContainerBuilder
  alias Testcontainers.Container
  alias Testcontainers.PortWaitStrategy
  alias Testcontainers.EmqxContainer

  @default_image "emqx"
  @default_tag "5.6.0"
  @default_image_with_tag "#{@default_image}:#{@default_tag}"
  @default_mqtt_port 1883
  @default_mqtts_port 8883
  @default_mqtt_over_ws_port 8083
  @default_mqtt_over_wss_port 8084
  @default_dashboard_port 18083
  @default_wait_timeout 60_000

  @enforce_keys [:image, :mqtt_port, :wait_timeout]
  defstruct [
    :image,
    :mqtt_port,
    :mqtts_port,
    :mqtt_over_ws_port,
    :mqtt_over_wss_port,
    :dashboard_port,
    :wait_timeout,
    check_image: &__MODULE__.default_image_checker/1
  ]

  @doc """
  Creates a new `EmqxContainer` struct with default configurations.
  """
  def new do
    %__MODULE__{
      image: @default_image_with_tag,
      wait_timeout: @default_wait_timeout,
      mqtt_port: @default_mqtt_port,
      mqtts_port: @default_mqtts_port,
      mqtt_over_ws_port: @default_mqtt_over_ws_port,
      mqtt_over_wss_port: @default_mqtt_over_wss_port,
      dashboard_port: @default_dashboard_port
    }
  end

  @doc """
  Overrides the default image used for the Emqx container.

  ## Examples

      iex> config = EmqxContainer.new()
      iex> new_config = EmqxContainer.with_image(config, "emqx:xyz")
      iex> new_config.image
      "emqx:xyz"
  """
  def with_image(%__MODULE__{} = config, image) when is_binary(image) do
    %{config | image: image}
  end

  def with_ports(
        %__MODULE__{} = config,
        mqtt_port \\ @default_mqtt_port,
        mqtts_port \\ @default_mqtts_port,
        mqtt_over_ws_port \\ @default_mqtt_over_ws_port,
        mqtt_over_wss_port \\ @default_mqtt_over_wss_port,
        dashboard_port \\ @default_dashboard_port
      ) do
    %{
      config
      | mqtt_port: mqtt_port,
        mqtts_port: mqtts_port,
        mqtt_over_ws_port: mqtt_over_ws_port,
        mqtt_over_wss_port: mqtt_over_wss_port,
        dashboard_port: dashboard_port
    }
  end

  @doc """
  Set the method to check the image compliance.
  """
  def with_check_image(%__MODULE__{} = config, check_image) when is_function(check_image) do
    %__MODULE__{config | check_image: check_image}
  end

  def default_image_checker(image), do: String.starts_with?(image, @default_image)

  @doc """
  Retrieves the default Docker image for the Emqx container.
  """
  def default_image, do: @default_image

  @doc """
  Returns the address on the _host machine_ where the Emqx container is listening.
  """
  def host, do: Testcontainers.get_host()

  @doc """
  Returns the port on the _host machine_ where the Emqx container is listening.
  """
  def mqtt_port(%Container{} = container),
    do: Container.mapped_port(container, @default_mqtt_port)

  defimpl ContainerBuilder do
    import Container

    @doc """
    Builds a new container instance based on the provided configuration.
    """
    @impl true
    def build(%EmqxContainer{} = config) do
      new(config.image)
      |> with_exposed_ports(exposed_ports(config))
      |> with_waiting_strategies(waiting_strategies(config))
      |> with_check_image(config.check_image)
      |> valid_image!()
    end

    defp exposed_ports(config),
      do: [
        config.mqtt_port,
        config.mqtts_port,
        config.mqtt_over_ws_port,
        config.mqtt_over_wss_port,
        config.dashboard_port
      ]

    defp waiting_strategies(config),
      do: [
        PortWaitStrategy.new(EmqxContainer.host(), config.mqtt_port, config.wait_timeout, 1000),
        PortWaitStrategy.new(EmqxContainer.host(), config.mqtts_port, config.wait_timeout, 1000),
        PortWaitStrategy.new(
          EmqxContainer.host(),
          config.mqtt_over_ws_port,
          config.wait_timeout,
          1000
        ),
        PortWaitStrategy.new(
          EmqxContainer.host(),
          config.mqtt_over_wss_port,
          config.wait_timeout,
          1000
        ),
        PortWaitStrategy.new(
          EmqxContainer.host(),
          config.dashboard_port,
          config.wait_timeout,
          1000
        )
      ]

    @impl true
    # TODO Implement the `after_start/3` function for the `ContainerBuilder` protocol.
    def after_start(_config, _container, _conn), do: :ok
  end
end
