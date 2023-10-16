# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule Testcontainers.Container.PostgresContainer do
  @moduledoc """
  Functions to build and interact with PostgreSql containers.
  """

  alias Testcontainers.Container
  alias Testcontainers.WaitStrategy.CommandWaitStrategy

  @postgres_port 5432

  @doc """
  Builds a PostgreSql container.

  Uses PostgreSql 13.1 by default, but a custom image can also be set.

  ## Options

  - `username` sets the username for the user
  - `password` sets the password for the user
  - `database` sets the name of the database
  """
  def new(image \\ "postgres:13.1", opts \\ []) do
    username = Keyword.get(opts, :username, "test")
    database = Keyword.get(opts, :database, "test")
    password = Keyword.get(opts, :password, "test")

    Container.new(
      image,
      exposed_ports: [@postgres_port],
      environment: %{
        POSTGRES_USER: username,
        POSTGRES_PASSWORD: password,
        POSTGRES_DB: database
      }
    )
    |> Container.with_waiting_strategy(wait_strategy(username, database))
  end

  @doc """
  Returns the port on the _host machine_ where the MySql container is listening.
  """
  def port(%Container{} = container), do: Container.mapped_port(container, @postgres_port)

  @doc """
  Returns the connection parameters to connect to the database from the _host machine_.
  """
  def connection_parameters(%Container{} = container) do
    [
      hostname: "localhost",
      port: port(container),
      username: container.environment[:POSTGRES_USER],
      password: container.environment[:POSTGRES_PASSWORD],
      database: container.environment[:POSTGRES_DB]
    ]
  end

  defp wait_strategy(username, database) do
    CommandWaitStrategy.new(
      ["sh", "-c", "pg_isready -U #{username} -d #{database} -h localhost"],
      10000
    )
  end
end
