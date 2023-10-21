# SPDX-License-Identifier: MIT
defmodule Testcontainers.Container.MongodbContainer do
  @moduledoc """
  Module for building Mongodb container configurations.

  This module provides functions for creating and manipulating configurations for Mongodb containers.
  It allows the setting of specific parameters like image, username, password,
  and other parameters related to the Mongodb container.
  """

  alias Testcontainers.WaitStrategy.LogWaitStrategy
  alias Testcontainers.Container.MongodbContainer
  alias Testcontainers.ContainerBuilder
  alias Testcontainers.Container

  @default_image "mongo"
  @default_tag "7"
  @default_port 27017
  @wait_timeout 60_000

  defstruct image: "#{@default_image}:#{@default_tag}",
            wait_timeout: @wait_timeout,
            port: @default_port,
            user: "test",
            password: "test",
            database: "test"

  @doc """
  Creates a new `MongodbContainer` struct with default attributes.
  """
  def new, do: %__MODULE__{}

  @doc """
  Sets the `image` of the Ceph container configuration.

  ## Examples

      iex> config = MongodbContainer.new()
      iex> new_config = MongodbContainer.with_image(config, "mongodb/alternative")
      iex> new_config.image
      "mongodb/alternative"
  """
  def with_image(%__MODULE__{} = config, image) when is_binary(image) do
    %{config | image: image}
  end

  @doc """
  Sets the `access_key` used for authentication with the Mongodb container.

  ## Examples

      iex> config = MongodbContainer.new()
      iex> new_config = MongodbContainer.with_user(config, "user")
      iex> new_config.user
      "user"
  """
  def with_user(%__MODULE__{} = config, user) when is_binary(user) do
    %{config | user: user}
  end

  @doc """
  Overrides the default database used for the Mongodb container.

  ## Examples

      iex> config = MongodbContainer.new()
      iex> new_config = MongodbContainer.with_database(config, "another-database")
      iex> new_config.database
      "another-database"
  """
  def with_database(%__MODULE__{} = config, database) when is_binary(database) do
    %{config | database: database}
  end

  @doc """
  Sets the `secret_key` used for authentication with the Mongodb container.

  ## Examples

      iex> config = MongodbContainer.new()
      iex> new_config = MongodbContainer.with_password(config, "password")
      iex> new_config.password
      "password"
  """
  def with_password(%__MODULE__{} = config, password) when is_binary(password) do
    %{config | password: password}
  end

  @doc """
  Overrides the default port used for the Mongodb container.

  Note: this will not change what port the docker container is listening to internally.

  ## Examples

      iex> config = MongodbContainer.new()
      iex> new_config = MongodbContainer.with_port(config, 3307)
      iex> new_config.port
      3307
  """
  def with_port(%__MODULE__{} = config, port) when is_integer(port) or is_tuple(port) do
    %{config | port: port}
  end

  @doc """
  Retrieves the default exposed port for the Mongodb container.
  """
  def default_port, do: @default_port

  @doc """
  Retrieves the default Docker image for the Mongodb container.
  """
  def default_image, do: @default_image

  @doc """
  Retrieves the default Docker image including tag for the Mongodb container.
  """
  def default_image_with_tag, do: @default_image <> ":" <> @default_tag

  @doc """
  Returns the port on the _host machine_ where the Mongodb container is listening.
  """
  def port(%Container{} = container), do: Container.mapped_port(container, @default_port)

  defimpl ContainerBuilder do
    @impl true
    def build(%MongodbContainer{} = config, _options) do
      import Container

      port_fn =
        case config.port do
          {exposed_port, host_port} ->
            fn container -> with_fixed_port(container, exposed_port, host_port) end

          port ->
            fn container -> with_exposed_port(container, port) end
        end

      new(config.image)
      |> Kernel.then(port_fn)
      |> with_environment(:MONGO_INITDB_ROOT_USERNAME, config.user)
      |> with_environment(:MONGO_INITDB_ROOT_PASSWORD, config.password)
      |> with_environment(:MONGO_INITDB_DATABASE, config.database)
      |> with_waiting_strategy(LogWaitStrategy.new(~r/.*Waiting for connections.*/, config.wait_timeout, 1000))
    end
  end
end
