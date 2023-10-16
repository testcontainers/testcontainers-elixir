# Testcontainers

[![Hex.pm](https://img.shields.io/hexpm/v/testcontainers.svg)]()

> Testcontainers is an Elixir library that supports ExUnit tests, providing lightweight, throwaway instances of common databases, Selenium web browsers, or anything else that can run in a Docker container.

## Usage

test/a_simple_mysql_container_test.exs
```elixir
defmodule ASimpleMySqlContainerTest do
  use ExUnit.Case, async: true

  import Testcontainers.ExUnit

  alias Testcontainers.Container.MySqlContainer

  describe "with default configuration" do
    container(:mysql, MySqlContainer.new())

    test "provides a ready-to-use mysql container", %{mysql: mysql} do
      assert mysql.environment[:MYSQL_MAJOR] == "8.0"
    end
  end
```

## Configure logging

Testcontainers will not log anything, unless the global log level is set to debug, which is the default log level for new mix projects.

You can suppress this debug logging globally for tests in config/test.exs like this:

```elixir 
import Config

config :logger, level: :warning
```

If you want to bring back the logs of Testcontainers later, you can change log level specifically like this in config/test.exs:

```elixir
config :testcontainers,
  log_level: :warning
```

If you have a lot of libraries and code that have different log levels, your config/test.exs could look like this if you use Testcontainers:

```elixir 
import Config

config :logger, level: :warning

config :testcontainers,
  log_level: :warning
```

This will set everything to :warning, including Testcontainers default log level.

## Contribution

Do you want to contribute? Find spots to improve on, fire up an issue and get the discussion going.
