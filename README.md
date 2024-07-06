# Testcontainers

[![Hex.pm](https://img.shields.io/hexpm/v/testcontainers.svg)](https://hex.pm/packages/testcontainers)

> Testcontainers is an Elixir library that supports ExUnit tests, providing lightweight, throwaway instances of common databases, Selenium web browsers, or anything else that can run in a Docker container.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [API Documentation](#api-documentation)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)

## Prerequisites

Before you begin, ensure you have met the following requirements:
- You have installed the latest version of [Elixir](https://elixir-lang.org/install.html)
- You have a Docker runtime installed
- You are familiar with Elixir and Docker basics

## Installation

To add Testcontainers to your project, follow these steps:

1. Add `testcontainers` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:testcontainers, "~> x.x.x"}
  ]
end
```

2. Run mix deps.get

3. Add the following to test/test_helper.exs

```elixir
Testcontainers.start_link()
```

## Usage

This section explains how to use the Testcontainers library in your own project.

### Basic usage

You can use generic container api, where you have to define everything yourself:

```elixir
{:ok, _} = Testcontainers.start_link()
config = %Testcontainers.Container{image: "redis:5.0.3-alpine"}
{:ok, container} = Testcontainers.start_container(config)
```

Or you can use one of many predefined containers like `RedisContainer`, that has waiting strategies among other things defined up front with good defaults:

```elixir
{:ok, _} = Testcontainers.start_link()
config = Testcontainers.RedisContainer.new()
{:ok, container} = Testcontainers.start_container(config)
```

If you want to use a predefined container, such as `RedisContainer`, with an alternative image, for example, `valkey/valkey`, it's possible:

```elixir
{:ok, _} = Testcontainers.start_link()
config =
  Testcontainers.RedisContainer.new()
  |> Testcontainers.RedisContainer.with_image("valkey/valkey:latest")
  |> Testcontainers.RedisContainer.with_check_image("valkey/valkey")
{:ok, container} = Testcontainers.start_container(config)
```

### ExUnit tests

Given you have added Testcontainers.start_link() to test_helper.exs:

```elixir
setup 
  config = Testcontainers.RedisContainer.new()
  {:ok, container} = Testcontainers.start_container(config)
  ExUnit.Callbacks.on_exit(fn -> Testcontainers.stop_container(container.container_id) end)
  {:ok, %{redis: container}}
end
```

there is a macro that can simplify this down to a oneliner:

```elixir
import Testcontainers.ExUnit

container(:redis, Testcontainers.RedisContainer.new())
```

### In a Phoenix project:

To start a postgres container when running tests, that also enables testing of application initialization with database calls at startup, add this in application.ex:

```elixir
  # in config/dev.exs:
  config :testcontainers, 
    enabled: true
    database: "hello_dev"

  # in config/test.exs:
  config :testcontainers, 
    enabled: true

  # in lib/hello/application.ex:
  @impl true
  def start(_type, _args) do
    if Application.get_env(:testcontainers, :enabled, false) do
      {:ok, _container} =
        case Application.get_env(:testcontainers, :database) do
          nil ->
            Testcontainers.Ecto.postgres_container(app: :hello)

          database ->
            Testcontainers.Ecto.postgres_container(
              app: :hello,
              persistent_volume_name: "#{database}_data"
            )
        end
    end

    # .. other setup code
  end

  # in mix.exs
  # comment out test alias and setup aliases for ecto
  defp aliases do
    [
      setup: [
        "deps.get", 
        # "ecto.setup",
        "assets.setup", 
        "assets.build"
      ],
      # "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      # "ecto.reset": ["ecto.drop", "ecto.setup"],
      # test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      # ... SNIP
    ]
  end
```

This will start a postgres container that will be terminated when the test process ends.

The database config in config/test.exs will be temporarily updated in-memory with the random host port on the container, and other properties like username, password and database. In most cases these will default to "test" unless overridden.

See documentation on [Testcontainers.Ecto](https://hexdocs.pm/testcontainers/Testcontainers.Ecto.html) for more information about the options it can take.

There is an example repo here with a bare bones phoenix application, where the only changes are the use of the ecto function and removing the test alias that interferes with it:

[Phoenix example](./examples/phoenix_project)

There is also another example repo without Phoenix, just a bare mix project, which show cases that the ecto dependencies are in fact optional:

[Mix project](./examples/mix_project)

### Logging

By default, Testcontainers doesn't log anything. If you want Testcontainers to log, set the desired log level in config/test.exs:

```elixir
# config/test.exs

import Config 

config :testcontainers,
  log_level: :warning
```

## API Documentation

For more detailed information about the API, different container configurations, and advanced usage scenarios, please refer to the [API documentation](https://hexdocs.pm/testcontainers/api-reference.html).

## Contributing

We welcome your contributions! Please see our contributing guidelines (TBD) for more details on how to submit patches and the contribution workflow.

## License

Testcontainers is available under the MIT license. See the LICENSE file for more info.

## Contact

If you have any questions, issues, or want to contribute, feel free to contact us.

---

Thank you for using Testcontainers to test your Elixir applications!
