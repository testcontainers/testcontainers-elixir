# SPDX-License-Identifier: MIT
defmodule Testcontainers.MongoContainer do
  @behaviour Testcontainers.DatabaseBehaviour
  @moduledoc """
  Provides functionality for creating and managing Mongo container configurations.
  """

  alias Testcontainers.CommandWaitStrategy
  alias Testcontainers.Container
  alias Testcontainers.ContainerBuilder
  alias Testcontainers.MongoContainer

  import Testcontainers.Container, only: [is_valid_image: 1]

  @default_image "mongo"
  @default_tag "latest"
  @default_image_with_tag "#{@default_image}:#{@default_tag}"
  @default_user "test"
  @default_password "test"
  @default_database "test"
  @default_port 27_017
  @default_wait_timeout 180_000

  @type t :: %__MODULE__{}

  @enforce_keys [:image, :user, :password, :database, :port, :wait_timeout, :persistent_volume]
  defstruct [
    :image,
    :user,
    :password,
    :database,
    :port,
    :wait_timeout,
    :persistent_volume,
    check_image: @default_image,
    reuse: false
  ]

  @doc """
  Creates a new `MongoContainer` struct with default configurations.
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
  Overrides the default image used for the Mongo container.

  ## Examples

      iex> config = MongoContainer.new()
      iex> new_config = MongoContainer.with_image(config, "mongo:5")
      iex> new_config.image
      "mongo:5"
  """
  def with_image(%__MODULE__{} = config, image) when is_binary(image) do
    %{config | image: image}
  end

  @doc """
  Alias for `with_user/2`, matching Mongo naming in other implementations.
  """
  def with_username(%__MODULE__{} = config, username) when is_binary(username) do
    with_user(config, username)
  end

  @doc """
  Overrides the default user used for the Mongo container.

  ## Examples

      iex> config = MongoContainer.new()
      iex> new_config = MongoContainer.with_user(config, "another-user")
      iex> new_config.user
      "another-user"
  """
  def with_user(%__MODULE__{} = config, user) when is_binary(user) do
    %{config | user: user}
  end

  @doc """
  Overrides the default password used for the Mongo container.

  ## Examples

      iex> config = MongoContainer.new()
      iex> new_config = MongoContainer.with_password(config, "another-password")
      iex> new_config.password
      "another-password"
  """
  def with_password(%__MODULE__{} = config, password) when is_binary(password) do
    %{config | password: password}
  end

  @doc """
  Overrides the default database used for the Mongo container.

  ## Examples

      iex> config = MongoContainer.new()
      iex> new_config = MongoContainer.with_database(config, "another-database")
      iex> new_config.database
      "another-database"
  """
  def with_database(%__MODULE__{} = config, database) when is_binary(database) do
    %{config | database: database}
  end

  @doc """
  Overrides the default port used for the Mongo container.

  Note: this will not change what port the docker container is listening to internally.

  ## Examples

      iex> config = MongoContainer.new()
      iex> new_config = MongoContainer.with_port(config, 27018)
      iex> new_config.port
      27018
  """
  def with_port(%__MODULE__{} = config, port) when is_integer(port) or is_tuple(port) do
    %{config | port: port}
  end

  @doc """
  mounts persistent volume in Mongo data path used for the Mongo container.

  ## Examples

      iex> config = MongoContainer.new()
      iex> config = MongoContainer.with_persistent_volume(config, "data_volume")
      iex> config.persistent_volume
      "data_volume"
  """
  def with_persistent_volume(%__MODULE__{} = config, persistent_volume)
      when is_binary(persistent_volume) do
    %{config | persistent_volume: persistent_volume}
  end

  @doc """
  Mounts the default wait timeout used for the Mongo container.

  Note: this timeout will be used for each individual wait strategy.

  ## Examples

      iex> config = MongoContainer.new()
      iex> new_config = MongoContainer.with_wait_timeout(config, 8000)
      iex> new_config.wait_timeout
      8000
  """
  def with_wait_timeout(%__MODULE__{} = config, wait_timeout) when is_integer(wait_timeout) do
    %{config | wait_timeout: wait_timeout}
  end

  @doc """
  Set the regular expression to check the image validity.
  """
  def with_check_image(%__MODULE__{} = config, check_image) when is_valid_image(check_image) do
    %__MODULE__{config | check_image: check_image}
  end

  @doc """
  Set the reuse flag to reuse the container if it is already running.
  """
  def with_reuse(%__MODULE__{} = config, reuse) when is_boolean(reuse) do
    %__MODULE__{config | reuse: reuse}
  end

  @doc """
  Retrieves the default exposed port for the Mongo container.
  """
  def default_port, do: @default_port

  @doc """
  Retrieves the default Docker image for the Mongo container.
  """
  def default_image, do: @default_image

  @doc """
  Retrieves the default Docker image including tag for the Mongo container.
  """
  def default_image_with_tag, do: @default_image <> ":" <> @default_tag

  @doc """
  Returns the port on the _host machine_ where the Mongo container is listening.
  """
  def port(%Container{} = container), do: Testcontainers.get_port(container, @default_port)

  @doc """
  Returns the connection parameters to connect to the database from the _host machine_.
  """
  def connection_parameters(%Container{} = container) do
    [
      hostname: Testcontainers.get_host(container),
      port: port(container),
      username: container.environment[:MONGO_INITDB_ROOT_USERNAME],
      password: container.environment[:MONGO_INITDB_ROOT_PASSWORD],
      database: container.environment[:MONGO_INITDB_DATABASE]
    ]
  end

  @doc """
  Generates the MongoDB connection URL.

  ## Options
    * `:protocol` - URL scheme, defaults to `"mongodb"`.
    * `:username` - Overrides username from container env.
    * `:password` - Overrides password from container env.
    * `:database` - Overrides database from container env.
    * `:options` - Query options as map/keyword list.
  """
  def mongo_url(%Container{} = container, opts \\ []) when is_list(opts) do
    protocol = Keyword.get(opts, :protocol, "mongodb")
    username = Keyword.get(opts, :username, container.environment[:MONGO_INITDB_ROOT_USERNAME])
    password = Keyword.get(opts, :password, container.environment[:MONGO_INITDB_ROOT_PASSWORD])
    database = Keyword.get(opts, :database, container.environment[:MONGO_INITDB_DATABASE])
    query_string = opts |> Keyword.get(:options, []) |> encode_query_string()

    "#{protocol}://#{username}:#{password}@#{Testcontainers.get_host(container)}:#{port(container)}/#{database}#{query_string}"
  end

  @doc """
  Alias for `mongo_url/2`.
  """
  def database_url(%Container{} = container, opts \\ []), do: mongo_url(container, opts)

  defimpl ContainerBuilder do
    import Container

    @doc """
    Implementation of the `ContainerBuilder` protocol specific to `MongoContainer`.

    This function builds a new container configuration, ensuring the Mongo image is compatible, setting environment variables, and applying a waiting strategy for the container to be ready.

    The build process raises an `ArgumentError` if the specified container image is not compatible with the expected Mongo image.

    ## Examples

        # Assuming `ContainerBuilder.build/2` is called from somewhere in the application with a `MongoContainer` configuration:
        iex> config = MongoContainer.new()
        iex> built_container = ContainerBuilder.build(config, [])
        # `built_container` is now a ready-to-use `%Container{}` configured specifically for Mongo.

    ## Errors

    - Raises `ArgumentError` if the provided image is not compatible with the default Mongo image.
    """
    @spec build(MongoContainer.t()) :: Container.t()
    @impl true
    def build(%MongoContainer{} = config) do
      new(config.image)
      |> then(MongoContainer.container_port_fun(config.port))
      |> with_environment(:MONGO_INITDB_ROOT_USERNAME, config.user)
      |> with_environment(:MONGO_INITDB_ROOT_PASSWORD, config.password)
      |> with_environment(:MONGO_INITDB_DATABASE, config.database)
      |> then(MongoContainer.container_volume_fun(config.persistent_volume))
      |> with_waiting_strategy(
        CommandWaitStrategy.new(
          [
            "sh",
            "-c",
            "mongosh --eval \"db.adminCommand('ping')\" || mongo --eval \"db.adminCommand('ping')\""
          ],
          config.wait_timeout
        )
      )
      |> with_check_image(config.check_image)
      |> with_reuse(config.reuse)
      |> valid_image!()
    end

    @impl true
    def after_start(_config, _container, _conn), do: :ok
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
    fn container -> Container.with_bind_volume(container, volume, "/data/db") end
  end

  defp encode_query_string(options) when options in [nil, [], %{}], do: ""

  defp encode_query_string(options) when is_map(options) or is_list(options) do
    case URI.encode_query(options) do
      "" -> ""
      query -> "?" <> query
    end
  end
end
