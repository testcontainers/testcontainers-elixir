# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule TestcontainersElixir.Container.PostgresContainer do
  @moduledoc """
  Functions to build and interact with PostgreSql containers.
  """

  alias TestcontainersElixir.Container
  alias TestcontainersElixir.WaitStrategy.CommandWaitStrategy

  @postgres_port 5432
  @wait_strategy CommandWaitStrategy.new([
                   "pg_isready",
                   "-U",
                   "test",
                   "-d",
                   "test",
                   "-h",
                   "localhost"
                 ])

  @doc """
  Builds a PostgreSql container.

  Uses PostgreSql 13.1 by default, but a custom image can also be set.

  ## Options

  - `username` sets the username for the user
  - `password` sets the password for the user
  - `database` sets the name of the database
  """
  def new(image \\ "postgres:13.1", opts \\ []) do
    Container.new(
      image,
      exposed_ports: [@postgres_port],
      environment: %{
        POSTGRES_USER: Keyword.get(opts, :username, "test"),
        POSTGRES_PASSWORD: Keyword.get(opts, :password, "test"),
        POSTGRES_DB: Keyword.get(opts, :database, "test")
      },
      wait_strategy: @wait_strategy
    )
  end

  @doc """
  Returns the port on the _host machine_ where the MySql container is listening.
  """
  def port(%Container{} = container),
    do: with({:ok, port} <- Container.mapped_port(container, @postgres_port), do: port)

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
end
