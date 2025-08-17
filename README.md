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
    {:testcontainers, "~> 1.11"}
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

### Run tests in a Phoenix project (or any project for that matter)

To run/wrap testcontainers around a project use the testcontainers.run task.

`mix testcontainers.run [sub_task] [--database postgres|mysql] [--watch dir ...] [--db-volume VOLUME]`

to use postgres you can just run

`mix testcontainers.run test` since postgres is default and test is the default sub-task.

#### Examples:

```bash
# Run tests with PostgreSQL (default)
mix testcontainers.run test

# Run tests with MySQL
mix testcontainers.run test --database mysql

# Run Phoenix server with PostgreSQL and persistent volume
mix testcontainers.run phx.server --database postgres --db-volume my_postgres_data

# Run tests with MySQL and persistent volume
mix testcontainers.run test --database mysql --db-volume my_mysql_data

# Run tests with file watching
mix testcontainers.run test --watch lib --watch test
```

#### Persistent Volumes

The `--db-volume` parameter allows you to specify a persistent volume for database data. This ensures that your database data persists between container restarts. The volume name you provide will be used to create a Docker volume that gets mounted to the appropriate database data directory:

- **PostgreSQL**: Volume is mounted to `/var/lib/postgresql/data`
- **MySQL**: Volume is mounted to `/var/lib/mysql`

This is particularly useful when you want to maintain database state across test runs or development sessions.

in your config/test.exs you can then change the repo config to this:

```
config :my_app, MyApp.Repo,
  username: System.get_env("DB_USER") || "postgres",
  password: System.get_env("DB_PASSWORD") || "postgres",
  hostname: System.get_env("DB_HOST") || "localhost",
  port: System.get_env("DB_PORT") || "5432",
  database: "my_app_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2
```

Activate reuse of database containers started by mix task with adding `testcontainers.reuse.enable=true` in `~/.testcontainers.properties`. This is experimental.

You can pass arguments to the sub-task by appending them after the sub-task name. For example, to pass arguments to mix test:

`mix testcontainers.run test --exclude flaky --stale`

In the example above we are running tests while excluding flaky tests and using the --stale option.

### Logging

Testcontainers use the standard Logger, see https://hexdocs.pm/logger/Logger.html.

## API Documentation

For more detailed information about the API, different container configurations, and advanced usage scenarios, please refer to the [API documentation](https://hexdocs.pm/testcontainers/api-reference.html).

## Windows support

### Testcontainers Desktop

This is the supported way to use Testcontainers Elixir on Windows. Download Testcontainers Desktop, install it and everything just works.

### Native
You can run on windows natively with elixir and erlang. But its not really supported, but I have investigated and tried it out. These are my findings:

First install Visual Studio 2022 with Desktop development with C++.

Open visual studio dev shell. I do it by just opening an empty c++ project, then View -> Terminal.

Enable "Expose daemon on tcp://localhost:2375 without TLS" in Docker settings.

for powershell:

`$Env:DOCKER_HOST = "tcp://localhost:2375"`

for cmd:

`set DOCKER_HOST=tcp://localhost:2375`

Compile and run tests:

`mix deps.get`

`mix deps.compile`

`mix test`

## Contributing

We welcome your contributions! Please see our contributing guidelines (TBD) for more details on how to submit patches and the contribution workflow.

## License

Testcontainers is available under the MIT license. See the LICENSE file for more info.

## Contact

If you have any questions, issues, or want to contribute, feel free to contact us.

---

Thank you for using Testcontainers to test your Elixir applications!
