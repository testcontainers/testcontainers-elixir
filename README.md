# Testcontainers

[![Hex.pm](https://img.shields.io/hexpm/v/testcontainers.svg)]()

> Testcontainers is an Elixir library that supports ExUnit tests, providing lightweight, throwaway instances of common databases, Selenium web browsers, or anything else that can run in a Docker container.

## Usage

For automatic cleanup of docker containers created in tests, for example if testcontainers fails to stop and remove the container, its suggested to register a reaper genserver in test_helper.exs like this:

test/test_helper.exs
```elixir
{:ok, _} = Testcontainers.Reaper.start_link()
ExUnit.start()
```

test/mysql_container_test.exs
```elixir
defmodule MySqlContainerTest do
  use ExUnit.Case, async: true

  import Testcontainers.ExUnit

  alias Testcontainers.Container.MySqlContainer

  describe "with default configuration" do
    container(:mysql, MySqlContainer.new())

    test "provides a ready-to-use mysql container", %{mysql: mysql} do
      assert true

      # if you want to test like below, add 
      # {:myxql, "~> 0.6.0", only: [:dev, :test]},
      # to mix.exs and run mix deps.get

      #{:ok, pid} = MyXQL.start_link(MySqlContainer.connection_parameters(mysql))
      #assert %{num_rows: 1} = MyXQL.query!(pid, "SELECT 1", [])
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
