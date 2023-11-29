# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule Testcontainers.MySqlContainer do
  @behaviour Testcontainers.DatabaseBehaviour
  @moduledoc """
  Provides functionality for creating and managing MySQL container configurations.
  """

  alias Testcontainers.Container
  alias Testcontainers.ContainerBuilder
  alias Testcontainers.MySqlContainer
  alias Testcontainers.LogWaitStrategy

  @default_image "mysql"
  @default_tag "8"
  @default_image_with_tag "#{@default_image}:#{@default_tag}"
  @default_user "test"
  @default_password "test"
  @default_database "test"
  @default_port 3306
  @default_wait_timeout 180_000

  @enforce_keys [:image, :user, :password, :database, :port, :wait_timeout, :persistent_volume]
  defstruct [:image, :user, :password, :database, :port, :wait_timeout, :persistent_volume]

  @doc """
  Creates a new `MySqlContainer` struct with default configurations.
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
  Overrides the default image used for the MySQL container.

  ## Examples

      iex> config = MySqlContainer.new()
      iex> new_config = MySqlContainer.with_image(config, "mysql:4")
      iex> new_config.image
      "mysql:4"
  """
  def with_image(%__MODULE__{} = config, image) when is_binary(image) do
    %{config | image: image}
  end

  @doc """
  Overrides the default user used for the MySQL container.

  ## Examples

      iex> config = MySqlContainer.new()
      iex> new_config = MySqlContainer.with_user(config, "another-user")
      iex> new_config.user
      "another-user"
  """
  def with_user(%__MODULE__{} = config, user) when is_binary(user) do
    %{config | user: user}
  end

  @doc """
  Overrides the default password used for the MySQL container.

  ## Examples

      iex> config = MySqlContainer.new()
      iex> new_config = MySqlContainer.with_password(config, "another-password")
      iex> new_config.password
      "another-password"
  """
  def with_password(%__MODULE__{} = config, password) when is_binary(password) do
    %{config | password: password}
  end

  @doc """
  Overrides the default database used for the MySQL container.

  ## Examples

      iex> config = MySqlContainer.new()
      iex> new_config = MySqlContainer.with_database(config, "another-database")
      iex> new_config.database
      "another-database"
  """
  def with_database(%__MODULE__{} = config, database) when is_binary(database) do
    %{config | database: database}
  end

  @doc """
  Overrides the default port used for the MySQL container.

  Note: this will not change what port the docker container is listening to internally.

  ## Examples

      iex> config = MySqlContainer.new()
      iex> new_config = MySqlContainer.with_port(config, 3307)
      iex> new_config.port
      3307
  """
  def with_port(%__MODULE__{} = config, port) when is_integer(port) or is_tuple(port) do
    %{config | port: port}
  end

  def with_persistent_volume(%__MODULE__{} = config, persistent_volume)
      when is_binary(persistent_volume) do
    %{config | persistent_volume: persistent_volume}
  end

  @doc """
  Overrides the default wait timeout used for the MySQL container.

  Note: this timeout will be used for each individual wait strategy.

  ## Examples

      iex> config = MySqlContainer.new()
      iex> new_config = MySqlContainer.with_wait_timeout(config, 8000)
      iex> new_config.wait_timeout
      8000
  """
  def with_wait_timeout(%__MODULE__{} = config, wait_timeout) when is_integer(wait_timeout) do
    %{config | wait_timeout: wait_timeout}
  end

  @doc """
  Retrieves the default exposed port for the MySQL container.
  """
  def default_port, do: @default_port

  @doc """
  Retrieves the default Docker image for the MySQL container.
  """
  def default_image, do: @default_image

  @doc """
  Retrieves the default Docker image including tag for the MySQL container.
  """
  def default_image_with_tag, do: @default_image <> ":" <> @default_tag

  @doc """
  Returns the port on the _host machine_ where the MySql container is listening.
  """
  def port(%Container{} = container), do: Container.mapped_port(container, @default_port)

  @doc """
  Returns the connection parameters to connect to the database from the _host machine_.
  """
  def connection_parameters(%Container{} = container) do
    [
      hostname: Testcontainers.get_host(),
      port: port(container),
      username: container.environment[:MYSQL_USER],
      password: container.environment[:MYSQL_PASSWORD],
      database: container.environment[:MYSQL_DATABASE]
    ]
  end

  defimpl ContainerBuilder do
    import Container

    @doc """
    Implementation of the `ContainerBuilder` protocol specific to `MySqlContainer`.

    This function builds a new container configuration, ensuring the MySQL image is compatible, setting environment variables, and applying a waiting strategy for the container to be ready.

    The build process raises an `ArgumentError` if the specified container image is not compatible with the expected MySql image.

    ## Examples

        # Assuming `ContainerBuilder.build/2` is called from somewhere in the application with a `MySqlContainer` configuration:
        iex> config = MySqlContainer.new()
        iex> built_container = ContainerBuilder.build(config, [])
        # `built_container` is now a ready-to-use `%Container{}` configured specifically for Mysql.

    ## Errors

    - Raises `ArgumentError` if the provided image is not compatible with the default MySql image.
    """
    @spec build(%MySqlContainer{}) :: %Container{}
    @impl true
    def build(%MySqlContainer{} = config) do
      if not String.starts_with?(config.image, MySqlContainer.default_image()) do
        raise ArgumentError,
          message:
            "Image #{config.image} is not compatible with #{MySqlContainer.default_image()}"
      end

      new(config.image)
      |> then(MySqlContainer.container_port_fun(config.port))
      |> with_environment(:MYSQL_USER, config.user)
      |> with_environment(:MYSQL_PASSWORD, config.password)
      |> with_environment(:MYSQL_DATABASE, config.database)
      |> then(MySqlContainer.container_volume_fun(config.persistent_volume))
      |> with_environment(:MYSQL_RANDOM_ROOT_PASSWORD, "yes")
      |> with_waiting_strategy(
        LogWaitStrategy.new(~r/.*port: 3306  MySQL Community Server.*/, config.wait_timeout)
      )
    end

    @impl true
    @spec is_starting(%MySqlContainer{}, %Container{}) :: any()
    def is_starting(_config, _container), do: nil
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
    fn container -> Container.with_bind_volume(container, volume, "/var/lib/mysql") end
  end
end

defmodule Testcontainers.Container.MySqlContainer do
  @moduledoc """
  Deprecated. Use `Testcontainers.MySqlContainer` instead.

  This module is kept for backward compatibility and will be removed in future releases.
  """

  @deprecated "Use Testcontainers.MySqlContainer instead"

  defdelegate new, to: Testcontainers.MySqlContainer
  defdelegate with_image(self, image), to: Testcontainers.MySqlContainer
  defdelegate with_user(self, user), to: Testcontainers.MySqlContainer
  defdelegate with_password(self, password), to: Testcontainers.MySqlContainer
  defdelegate with_database(self, database), to: Testcontainers.MySqlContainer
  defdelegate with_port(self, port), to: Testcontainers.MySqlContainer
  defdelegate with_wait_timeout(self, wait_timeout), to: Testcontainers.MySqlContainer
  defdelegate port(self), to: Testcontainers.MySqlContainer
  defdelegate connection_parameters(self), to: Testcontainers.MySqlContainer
  defdelegate default_image_with_tag, to: Testcontainers.MySqlContainer
  defdelegate default_port, to: Testcontainers.PostgresContainer
end
