# Testcontainers

[![Hex.pm](https://img.shields.io/hexpm/v/testcontainers.svg)](https://hex.pm/packages/testcontainers)

> Testcontainers is an Elixir library that supports ExUnit tests, providing lightweight, throwaway instances of common databases, Selenium web browsers, or anything else that can run in a Docker container.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
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
    {:testcontainers, "~> X.XX", only: [:test, :dev]}
  ]
end
```

Replace X.XX with the current major and minor version.

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

`mix testcontainers.run [sub_task] [--database postgres|mysql] [--db-volume VOLUME]`

to use postgres you can just run

`mix testcontainers.run test` since postgres is default and test is the default sub-task.

#### Examples:

```bash
# Run tests with PostgreSQL (default)
MIX_ENV=test mix testcontainers.run test

# Run tests with MySQL
MIX_ENV=test mix testcontainers.run test --database mysql

# Run Phoenix server with PostgreSQL and persistent volume
mix testcontainers.run phx.server --database postgres --db-volume my_postgres_data

# Run tests with MySQL and persistent volume
MIX_ENV=test mix testcontainers.run test --database mysql --db-volume my_mysql_data

# Start Phoenix server with containerized DB (will keep running until stopped)
mix testcontainers.run phx.server --database postgres --db-volume my_dev_data
```

#### Persistent Volumes

The `--db-volume` parameter allows you to specify a persistent volume for database data. This ensures that your database data persists between container restarts. The volume name you provide will be used to create a Docker volume that gets mounted to the appropriate database data directory:

- **PostgreSQL**: Volume is mounted to `/var/lib/postgresql/data`
- **MySQL**: Volume is mounted to `/var/lib/mysql`

This is particularly useful when you want to maintain database state across test runs or development sessions.

#### Configuration (runtime.exs)

Instead of editing dev.exs or test.exs, you can let testcontainers set `DATABASE_URL` and use it from `config/runtime.exs` for dev and test:

```elixir
# config/runtime.exs

if config_env() in [:dev, :test] do
  if url = System.get_env("DATABASE_URL") do
    config :my_app, MyApp.Repo,
      url: url,
      pool: Ecto.Adapters.SQL.Sandbox,
      show_sensitive_data_on_connection_error: true,
      pool_size: 10
  end
end
```

This allows you to run your Phoenix server or tests with a containerized database without changing dev.exs or test.exs (remember to set MIX_ENV when running tests):

```bash
# Start Phoenix server with PostgreSQL container
mix testcontainers.run phx.server --database postgres

# Start Phoenix server with MySQL container
mix testcontainers.run phx.server --database mysql

# Start with persistent data
mix testcontainers.run phx.server --database postgres --db-volume my_dev_data
```

Activate reuse of database containers started by mix task with adding `testcontainers.reuse.enable=true` in `~/.testcontainers.properties`. This is experimental.

You can pass arguments to the sub-task by appending them after `--`. For example, to pass arguments to mix test:

`MIX_ENV=test mix testcontainers.run test -- --exclude flaky --stale`

In the example above we are running tests while excluding flaky tests and using the --stale option.

Note: MIX_ENV is not overridden by the run task. For tests, set it explicitly in the shell:

`MIX_ENV=test mix testcontainers.run test`

#### Backward Compatibility

For backward compatibility, the old `mix testcontainers.test` task is still available and works exactly as before. It automatically delegates to `mix testcontainers.run test`, so existing scripts and workflows will continue to work without modification:

```bash
# These commands are equivalent:
mix testcontainers.test --database mysql
mix testcontainers.run test --database mysql

# Both support all the same options:
mix testcontainers.test --database postgres --db-volume my_data
mix testcontainers.run test --database postgres --db-volume my_data
```

While the old task will continue to work, we recommend updating to `mix testcontainers.run` for new projects as it provides more flexibility by allowing you to run any Mix task, not just tests.

### Logging

Testcontainers use the standard Logger, see https://hexdocs.pm/logger/Logger.html.

## Configuration

### Pull policy

By default, Testcontainers pulls an image only when it isn't already present in the local Docker daemon. This avoids Docker Hub rate limits on repeated test runs. The policy per container can be overridden:

```elixir
alias Testcontainers.{Container, PullPolicy}

# pulled only if not present locally (default)
%Container{image: "redis:7", pull_policy: PullPolicy.pull_if_missing()}

# always pull, bypassing any cached image
%Container{image: "redis:7", pull_policy: PullPolicy.always_pull()}

# never pull; expect the image to exist locally
%Container{image: "redis:7", pull_policy: PullPolicy.never_pull()}

# conditional pull; pass a 2-arity function
%Container{
  image: "redis:7",
  pull_policy: PullPolicy.pull_condition(fn _config, _conn -> should_pull?() end)
}
```

The global default can also be set in `~/.testcontainers.properties` via `pull.policy` (`missing` — default, `always`, or `never`).

### Naming containers

Give a container a stable name so other containers on the same network can reference it by name:

```elixir
Testcontainers.Container.new("postgres:16")
|> Testcontainers.Container.with_name("my-postgres")
```

The name is passed straight through to Docker's `/containers/create` as the `name` query parameter, so the usual Docker rules apply (must be unique on the daemon, `[a-zA-Z0-9][a-zA-Z0-9_.-]+`).

### Private registries

If the image lives on a registry that requires authentication, Testcontainers automatically resolves credentials from the user's Docker config on image pull. The lookup order is:

1. `Container.auth` if set explicitly — always wins.
2. The `auths` map in `$DOCKER_CONFIG/config.json` (or `~/.docker/config.json` if `DOCKER_CONFIG` is unset). The registry host of the image is matched against entries in the map.
3. Anonymous pull.

Only the `auths` map is consulted; credential-helper binaries (`credsStore`, `credHelpers`) are not invoked. If an auto-resolved credential is rejected with a 4xx, the pull is retried once anonymously to keep stale entries in `config.json` from breaking pulls that would otherwise succeed without auth.

To log in before running tests:

```bash
docker login myregistry.example.com
```

### TLS-secured Docker hosts

Testcontainers recognizes TLS-secured Docker daemons out of the box. Point it at one with:

- `DOCKER_HOST=https://docker.example.internal:2376`, or
- `DOCKER_HOST=tcp://docker.example.internal:2376` plus `DOCKER_TLS_VERIFY=1`.

The client looks for `ca.pem`, `cert.pem`, and `key.pem` in the directory named by `DOCKER_CERT_PATH` (or `~/.docker` if unset); whichever files are present are used to build the SSL context, matching the Docker CLI's behavior. When `DOCKER_TLS_VERIFY` is unset, peer verification is disabled and a warning is logged.

### Ryuk under SELinux / rootless Docker

On distributions that enforce SELinux (for example Fedora), the Ryuk reaper container may be denied write access to the Docker socket unless it runs privileged. Enable it with either:

- the `ryuk.container.privileged=true` property in `~/.testcontainers.properties`, or
- the `TESTCONTAINERS_RYUK_CONTAINER_PRIVILEGED=true` environment variable (takes precedence over the property).

Ryuk only runs privileged when one of these is set to `true` or `1`.

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
