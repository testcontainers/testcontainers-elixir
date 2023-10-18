# Testcontainers

[![Hex.pm](https://img.shields.io/hexpm/v/testcontainers.svg)](https://hex.pm/packages/testcontainers)

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
end
```

## Start container directly in test helper

If you want to setup a globally shared database for all tests in the project, you can now configure and run a container inside the `test/test_helper.exs` file:

```elixir
import Testcontainers.ExUnit
alias Testcontainers.Container
alias Container.PostgresContainer

exposed_port = 5432
host_port = 2345

postgres =
  PostgresContainer.new("postgres:latest")
  |> Container.with_fixed_port(exposed_port, host_port)

{:ok, _} = run_container(postgres, on_exit: nil) # <- cannot use exunits on_exit callback here

ExUnit.start()
```

The container will be deleted by Ryuk after the test session ends.

## Configure logging

Testontainers doesn't log anything by default.

If you want Testcontainers to log, set the wanted log level in config/test.exs

```elixir
import Config 

config :testcontainers,
  log_level: :warning
```

## Contribution

Do you want to contribute? Find spots to improve on, fire up an issue and get the discussion going.
