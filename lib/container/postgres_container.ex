# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule Testcontainers.PostgresContainer do
  @behaviour Testcontainers.DatabaseBehaviour
  @moduledoc """
  Provides functionality for creating and managing Postgres container configurations.
  """

  alias Testcontainers.CommandWaitStrategy
  alias Testcontainers.PostgresContainer
  alias Testcontainers.Container
  alias Testcontainers.ContainerBuilder

  @default_image "postgres"
  @default_tag "15-alpine"
  @default_image_with_tag "#{@default_image}:#{@default_tag}"
  @default_user "test"
  @default_password "test"
  @default_database "test"
  @default_port 5432
  @default_wait_timeout 60_000

  @enforce_keys [:image, :user, :password, :database, :port, :wait_timeout, :persistent_volume]
  defstruct [:image, :user, :password, :database, :port, :wait_timeout, :persistent_volume]

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
      wait_timeout: @default_wait_timeout,
      persistent_volume: nil
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

  def with_persistent_volume(%__MODULE__{} = config, persistent_volume)
      when is_binary(persistent_volume) do
    %{config | persistent_volume: persistent_volume}
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
      hostname: Testcontainers.get_host(),
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
    @spec build(%PostgresContainer{}) :: %Container{}
    @impl true
    def build(%PostgresContainer{} = config) do
      if not String.starts_with?(config.image, PostgresContainer.default_image()) do
        raise ArgumentError,
          message:
            "Image #{config.image} is not compatible with #{PostgresContainer.default_image()}"
      end

      new(config.image)
      |> then(PostgresContainer.container_port_fun(config.port))
      |> with_environment(:POSTGRES_USER, config.user)
      |> with_environment(:POSTGRES_PASSWORD, config.password)
      |> with_environment(:POSTGRES_DB, config.database)
      |> then(PostgresContainer.container_volume_fun(config.persistent_volume))
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

    @impl true
    @spec is_starting(%PostgresContainer{}, %Container{}, %Tesla.Env{}) :: :ok
    def is_starting(_config, _container, _conn), do: :ok
  end

  @doc false
  def container_port_fun(nil), do: &Function.identity/1

  def container_port_fun({exposed_port, host_port}) do
    fn container -> Container.with_fixed_port(container, exposed_port, host_port) end
  end

  def container_port_fun(port) do
    fn container -> Container.with_exposed_port(container, port) end
  end

  @doc false
  def container_volume_fun(nil), do: &Function.identity/1

  def container_volume_fun(volume) when is_binary(volume) do
    fn container -> Container.with_bind_volume(container, volume, "/var/lib/postgresql/data") end
  end
end

defmodule Testcontainers.Container.PostgresContainer do
  @moduledoc """
  Deprecated. Use `Testcontainers.PostgresContainer` instead.

  This module is kept for backward compatibility and will be removed in future releases.
  """

  @deprecated "Use Testcontainers.PostgresContainer instead"

  defdelegate new, to: Testcontainers.PostgresContainer
  defdelegate with_image(self, image), to: Testcontainers.PostgresContainer
  defdelegate with_user(self, user), to: Testcontainers.PostgresContainer
  defdelegate with_password(self, password), to: Testcontainers.PostgresContainer
  defdelegate with_database(self, database), to: Testcontainers.PostgresContainer
  defdelegate with_port(self, port), to: Testcontainers.PostgresContainer
  defdelegate with_wait_timeout(self, wait_timeout), to: Testcontainers.PostgresContainer
  defdelegate port(self), to: Testcontainers.PostgresContainer
  defdelegate connection_parameters(self), to: Testcontainers.PostgresContainer
  defdelegate default_image_with_tag, to: Testcontainers.PostgresContainer
  defdelegate default_port, to: Testcontainers.PostgresContainer
end
