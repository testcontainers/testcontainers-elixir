# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule Testcontainers.Container.MySqlContainer do
  @moduledoc """
  Functions to build and interact with MySql containers.
  """

  alias Testcontainers.Container
  alias Testcontainers.WaitStrategy.CommandWaitStrategy

  @mysql_port 3306

  @doc """
  Builds a MySql container.

  Uses MySql 8.0 by default, but a custom image can also be set.

  ## Options

  - `username` sets the username for the user
  - `password` sets the password for the user
  - `database` sets the name of the database
  """
  def new(image \\ "mysql:8.0", opts \\ []) do
    username = Keyword.get(opts, :username, "test")
    password = Keyword.get(opts, :password, "test")
    database = Keyword.get(opts, :database, "test")

    Container.new(
      image,
      exposed_ports: [@mysql_port],
      environment: %{
        MYSQL_USER: username,
        MYSQL_PASSWORD: password,
        MYSQL_DATABASE: database,
        MYSQL_RANDOM_ROOT_PASSWORD: "yes"
      },
      wait_strategy: wait_strategy(username, password)
    )
  end

  @doc """
  Returns the port on the _host machine_ where the MySql container is listening.
  """
  def port(container), do: Container.mapped_port(container, @mysql_port)

  @doc """
  Returns the connection parameters to connect to the database from the _host machine_.
  """
  def connection_parameters(%Container{} = container) do
    [
      hostname: "localhost",
      port: port(container),
      username: container.environment[:MYSQL_USER],
      password: container.environment[:MYSQL_PASSWORD],
      database: container.environment[:MYSQL_DATABASE]
    ]
  end

  defp wait_strategy(username, password) do
    CommandWaitStrategy.new([
      "sh",
      "-c",
      "mysqladmin ping --user='#{username}' --password='#{password}' -h localhost | grep 'mysqld is alive'"
    ])
  end
end
