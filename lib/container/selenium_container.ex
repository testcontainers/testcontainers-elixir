# SPDX-License-Identifier: MIT
defmodule Testcontainers.SeleniumContainer do
  @moduledoc """
  Work in progress. Not stable for use yet. Not yet documented for this very reason.
  Can use https://github.com/stuart/elixir-webdriver for client in tests
  """
  alias Testcontainers.ContainerBuilder
  alias Testcontainers.Container
  alias Testcontainers.SeleniumContainer
  alias Testcontainers.PortWaitStrategy
  alias Testcontainers.LogWaitStrategy

  @default_image "selenium/standalone-chrome"
  @default_tag "118.0"
  @default_image_with_tag "#{@default_image}:#{@default_tag}"
  @default_port1 7900
  @default_port2 4400
  @default_wait_timeout 120_000

  @enforce_keys [:image, :port1, :port2, :wait_timeout]
  defstruct [:image, :port1, :port2, :wait_timeout]

  def new,
    do: %__MODULE__{
      image: @default_image_with_tag,
      wait_timeout: @default_wait_timeout,
      port1: @default_port1,
      port2: @default_port2
    }

  def with_image(%__MODULE__{} = config, image) when is_binary(image) do
    %{config | image: image}
  end

  def with_port1(%__MODULE__{} = config, port1) when is_integer(port1) do
    %{config | port1: port1}
  end

  def with_port2(%__MODULE__{} = config, port2) when is_integer(port2) do
    %{config | port2: port2}
  end

  def with_wait_timeout(%__MODULE__{} = config, wait_timeout) when is_integer(wait_timeout) do
    %{config | wait_timeout: wait_timeout}
  end

  def default_image, do: @default_image

  defimpl ContainerBuilder do
    import Container

    @log_regex ~r/.*(RemoteWebDriver instances should connect to|Selenium Server is up and running|Started Selenium Standalone).*\n/

    @spec build(%SeleniumContainer{}) :: %Container{}
    @impl true
    def build(%SeleniumContainer{} = config) do
      new(config.image)
      |> with_exposed_ports([config.port1, config.port2])
      |> with_waiting_strategies([
        LogWaitStrategy.new(@log_regex, config.wait_timeout, 1000),
        PortWaitStrategy.new("127.0.0.1", config.port1, config.wait_timeout, 1000),
        PortWaitStrategy.new("127.0.0.1", config.port2, config.wait_timeout, 1000)
      ])
      |> with_check_image(true)
      |> with_default_image(SeleniumContainer.default_image())
      |> valid_image!()
    end

    @impl true
    @spec after_start(%SeleniumContainer{}, %Container{}, %Tesla.Env{}) :: :ok
    def after_start(_config, _container, _conn), do: :ok
  end
end

defmodule Testcontainers.Container.SeleniumContainer do
  @moduledoc """
  Deprecated. Use `Testcontainers.SeleniumContainer` instead.

  This module is kept for backward compatibility and will be removed in future releases.
  """

  @deprecated "Use Testcontainers.SeleniumContainer instead"

  defdelegate new, to: Testcontainers.SeleniumContainer
  defdelegate with_image(self, image), to: Testcontainers.SeleniumContainer
  defdelegate with_port1(self, port), to: Testcontainers.SeleniumContainer
  defdelegate with_port2(self, port), to: Testcontainers.SeleniumContainer
  defdelegate with_wait_timeout(self, wait_timeout), to: Testcontainers.SeleniumContainer
end
