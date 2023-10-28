# SPDX-License-Identifier: MIT
defmodule Testcontainers.Container.SeleniumContainer do
  @moduledoc """
  Work in progress. Not stable for use yet. Not yet documented for this very reason.
  Can use https://github.com/stuart/elixir-webdriver for client in tests
  """
  alias Testcontainers.ContainerBuilder
  alias Testcontainers.Container
  alias Testcontainers.Container.SeleniumContainer
  alias Testcontainers.WaitStrategy.PortWaitStrategy
  alias Testcontainers.WaitStrategy.LogWaitStrategy

  @default_image "selenium/standalone-chrome"
  @default_tag "118.0"
  @default_image_with_tag "#{@default_image}:#{@default_tag}"
  # TODO find proper names for these two ports
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

  # TODO find proper name for this port
  def with_port1(%__MODULE__{} = config, port1) when is_integer(port1) do
    %{config | port1: port1}
  end

  # TODO find proper name for this port
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

    @spec build(%SeleniumContainer{}, keyword()) :: %Container{}
    @impl true
    def build(%SeleniumContainer{} = config, _options) do
      if not String.starts_with?(config.image, SeleniumContainer.default_image()) do
        raise ArgumentError,
          message:
            "Image #{config.image} is not compatible with #{SeleniumContainer.default_image()}"
      end

      new(config.image)
      |> with_exposed_ports([config.port1, config.port2])
      |> with_waiting_strategies([
        LogWaitStrategy.new(@log_regex, config.wait_timeout, 1000),
        PortWaitStrategy.new("127.0.0.1", config.port1, config.wait_timeout, 1000),
        PortWaitStrategy.new("127.0.0.1", config.port2, config.wait_timeout, 1000)
      ])
    end
  end
end
