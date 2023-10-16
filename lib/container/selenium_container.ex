defmodule Testcontainers.Container.SeleniumContainer do
  @moduledoc """
  Work in progress. Not stable for use yet.
  Can use https://github.com/stuart/elixir-webdriver for client in tests
  """

  alias Testcontainers.Container
  alias Testcontainers.WaitStrategy.PortWaitStrategy
  alias Testcontainers.WaitStrategy.LogWaitStrategy

  @default_image "selenium/standalone-chrome:latest"
  @log_regex ~r/.*(RemoteWebDriver instances should connect to|Selenium Server is up and running|Started Selenium Standalone).*\n/
  @wait_strategies [
    PortWaitStrategy.new("127.0.0.1", 4400, 15_000, 1000),
    PortWaitStrategy.new("127.0.0.1", 7900, 15_000, 1000),
    LogWaitStrategy.new(@log_regex, 60_000, 1000)
  ]

  def new(options \\ []) do
    image = Keyword.get(options, :image, @default_image)

    Container.new(image)
    |> Container.with_exposed_ports([4400, 7900])
    |> Container.with_waiting_strategies(@wait_strategies)
  end
end
