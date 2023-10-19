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
- You have a [Docker](https://www.docker.com/products/docker-desktop) installed and running
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

## Usage

This section explains how to use the Testcontainers library in your own project.

### Simple example

Here's a simple example of how to use a MySQL container in your tests:

```elixir
# test/a_simple_mysql_container_test.exs

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

### Gloab Setup

If you prefer to set up a globally shared database for all tests in the project, you can configure and run a container inside the test/test_helper.exs file:

```elixir
# test/test_helper.exs

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
