# Testcontainers

> Testcontainers is an Elixir library that supports ExUnit tests, providing lightweight, throwaway instances of common databases, Selenium web browsers, or anything else that can run in a Docker container.

## Usage

For automatic cleanup of docker containers created in tests, for example if testcontainers fails to stop and remove the container, its suggested to register a reaper genserver in test_helper.exs like this:

test/test_helper.exs
```elixir
{:ok, _} = Testcontainers.Reaper.start_link()
ExUnit.start()
```

test/myswql_container_test.exs
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

## Contribution

Do you want to contribute? Find spots to improve on, fire up an issue and get the discussion going.