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

  import Testcontainers.Container, only: [is_valid_image: 1]

  @default_image "selenium/standalone-chrome"
  @default_tag "118.0"
  @default_image_with_tag "#{@default_image}:#{@default_tag}"
  @default_port1 7900
  @default_port2 4400
  @default_wait_timeout 120_000

  @enforce_keys [:image, :port1, :port2, :wait_timeout]
  defstruct [
    :image,
    :port1,
    :port2,
    :wait_timeout,
    check_image: @default_image,
    reuse: false
  ]

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

  def default_image, do: @default_image

  defimpl ContainerBuilder do
    import Container

    @spec build(%SeleniumContainer{}) :: %Container{}
    @impl true
    def build(%SeleniumContainer{} = config) do
      new(config.image)
      |> with_exposed_ports([config.port1, config.port2])
      |> with_waiting_strategies([
        LogWaitStrategy.new(~r/.*(RemoteWebDriver instances should connect to|Selenium Server is up and running|Started Selenium Standalone).*\n/, config.wait_timeout, 1000),
        PortWaitStrategy.new("127.0.0.1", config.port1, config.wait_timeout, 1000),
        PortWaitStrategy.new("127.0.0.1", config.port2, config.wait_timeout, 1000)
      ])
      |> with_check_image(config.check_image)
      |> with_reuse(config.reuse)
      |> valid_image!()
    end

    @impl true
    def after_start(_config, _container, _conn), do: :ok
  end
end
