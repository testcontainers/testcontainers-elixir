# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule Testcontainers.Container.PostgresContainer do
  @behaviour Testcontainers.Container.Behaviours.Database
  @moduledoc """
  Provides functionality for creating and managing Postgres container configurations.

  This module includes helper methods for setting up a Postgres container with specific parameters such as image, user, password, database, and more.
  """

  alias Testcontainers.WaitStrategy.CommandWaitStrategy
  alias Testcontainers.Container.PostgresContainer
  alias Testcontainers.Container
  alias Testcontainers.ContainerBuilder

  @default_image "postgres"
  @default_tag "15"
  @default_image_with_tag "#{@default_image}:#{@default_tag}"
  @default_user "test"
  @default_password "test"
  @default_database "test"
  @default_port 5432
  @default_wait_timeout 60_000

  @enforce_keys [:image, :user, :password, :database, :port, :wait_timeout]
  defstruct [:image, :user, :password, :database, :port, :wait_timeout]

  @doc """
  Creates a new `PostgresContainer` struct with default configurations.
  """
  def new,
    do: %__MODULE__{
      image: @default_image_with_tag,
      user: @default_user,
      password: @default_password,
      database: @default_database,
      port: @default_port,
      wait_timeout: @default_wait_timeout
    }

  @doc """
  Overrides the default image used for the Postgres container.

  ## Examples

      iex> config = PostgresContainer.new()
      iex> new_config = PostgresContainer.with_image(config, "postgres:12")
      iex> new_config.image
      "postgres:12"
  """
  def with_image(%__MODULE__{} = config, image) when is_binary(image) do
    %{config | image: image}
  end

  @doc """
  Overrides the default user used for the Postgres container.

  ## Examples

      iex> config = PostgresContainer.new()
      iex> new_config = PostgresContainer.with_user(config, "another-user")
      iex> new_config.user
      "another-user"
  """
  def with_user(%__MODULE__{} = config, user) when is_binary(user) do
    %{config | user: user}
  end

  @doc """
  Overrides the default password used for the Postgres container.

  ## Examples

      iex> config = PostgresContainer.new()
      iex> new_config = PostgresContainer.with_password(config, "another-password")
      iex> new_config.password
      "another-password"
  """
  def with_password(%__MODULE__{} = config, password) when is_binary(password) do
    %{config | password: password}
  end

  @doc """
  Overrides the default database used for the Postgres container.

  ## Examples

      iex> config = PostgresContainer.new()
      iex> new_config = PostgresContainer.with_database(config, "another-database")
      iex> new_config.database
      "another-database"
  """
  def with_database(%__MODULE__{} = config, database) when is_binary(database) do
    %{config | database: database}
  end

  @doc """
  Overrides the default port used for the Postgres container.

  Note: this will not change what port the docker container is listening to internally.

  ## Examples

      iex> config = PostgresContainer.new()
      iex> new_config = PostgresContainer.with_port(config, 2345)
      iex> new_config.port
      2345
  """
  def with_port(%__MODULE__{} = config, port) when is_integer(port) or is_tuple(port) do
    %{config | port: port}
  end

  @doc """
  Overrides the default wait timeout used for the Postgres container.

  Note: this timeout will be used for each individual wait strategy.

  ## Examples

      iex> config = PostgresContainer.new()
      iex> new_config = PostgresContainer.with_wait_timeout(config, 8000)
      iex> new_config.wait_timeout
      8000
  """
  def with_wait_timeout(%__MODULE__{} = config, wait_timeout) when is_integer(wait_timeout) do
    %{config | wait_timeout: wait_timeout}
  end

  @doc """
  Retrieves the default exposed port for the Postgres container.
  """
  def default_port, do: @default_port

  @doc """
  Retrieves the default Docker image for the Postgres container.
  """
  def default_image, do: @default_image

  @doc """
  Retrieves the default Docker image including tag for the Postgres container.
  """
  def default_image_with_tag, do: @default_image <> ":" <> @default_tag

  @doc """
  Returns the port on the _host machine_ where the Postgres container is listening.
  """
  def port(%Container{} = container), do: Container.mapped_port(container, @default_port)

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

  defimpl ContainerBuilder do
    import Container

    @doc """
    Implementation of the `ContainerBuilder` protocol specific to `PostgresContainer`.

    This function builds a new container configuration, ensuring the Postgres image is compatible, setting environment variables, and applying a waiting strategy for the container to be ready.

    The build process raises an `ArgumentError` if the specified container image is not compatible with the expected Postgres image.

    ## Examples

        # Assuming `ContainerBuilder.build/2` is called from somewhere in the application with a `PostgresContainer` configuration:
        iex> config = PostgresContainer.new()
        iex> built_container = ContainerBuilder.build(config, [])
        # `built_container` is now a ready-to-use `%Container{}` configured specifically for Postgres.

    ## Errors

    - Raises `ArgumentError` if the provided image is not compatible with the default Postgres image.
    """
    @spec build(%PostgresContainer{}, keyword()) :: %Container{}
    @impl true
    def build(%PostgresContainer{} = config, _options) do
      if not String.starts_with?(config.image, PostgresContainer.default_image()) do
        raise ArgumentError,
          message:
            "Image #{config.image} is not compatible with #{PostgresContainer.default_image()}"
      end

      port_fn =
        case config.port do
          {exposed_port, host_port} ->
            fn container -> with_fixed_port(container, exposed_port, host_port) end

          port ->
            fn container -> with_exposed_port(container, port) end
        end

      new(config.image)
      |> Kernel.then(port_fn)
      |> with_environment(:POSTGRES_USER, config.user)
      |> with_environment(:POSTGRES_PASSWORD, config.password)
      |> with_environment(:POSTGRES_DB, config.database)
      |> with_waiting_strategy(
        CommandWaitStrategy.new(
          [
            "sh",
            "-c",
            "pg_isready -U #{config.user} -d #{config.database} -h localhost"
          ],
          config.wait_timeout
        )
      )
    end
  end
end
