# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule Testcontainers.Container do
  alias Testcontainers.WaitStrategy
  alias Testcontainers.Reaper
  alias Testcontainers.Connection

  @enforce_keys [:image]

  defstruct [
    :image,
    cmd: nil,
    environment: %{},
    exposed_ports: [],
    wait_strategies: [],
    privileged: false,
    bind_mounts: [],
    labels: %{},
    auto_remove: true,
    container_id: nil
  ]

  @doc """
  A constructor function to make it easier to construct a container
  """
  def new(image, opts \\ []) when is_binary(image) do
    %__MODULE__{
      image: image,
      bind_mounts: opts[:bind_mounts] || [],
      cmd: opts[:cmd],
      environment: opts[:environment] || %{},
      exposed_ports: Keyword.get(opts, :exposed_ports, []),
      privileged: opts[:privileged] || false,
      auto_remove: opts[:auto_remove] || true,
      wait_strategies: opts[:wait_strategies] || []
    }
  end

  @doc """
  Sets a _waiting strategy_ for the _container_.
  """
  def with_waiting_strategy(%__MODULE__{} = config, wait_fn) do
    %__MODULE__{config | wait_strategies: [wait_fn | config.wait_strategies]}
  end

  @doc """
  Sets multiple _waiting strategies_ for the _container_.
  """
  def with_waiting_strategies(%__MODULE__{} = config, wait_fns) when is_list(wait_fns) do
    %__MODULE__{config | wait_strategies: wait_fns ++ config.wait_strategies}
  end

  @doc """
  Sets an _environment variable_ to the _container_.
  """
  def with_environment(%__MODULE__{} = config, key, value) do
    %__MODULE__{config | environment: Map.put(config.environment, key, value)}
  end

  @doc """
  Adds a _port_ to be exposed on the _container_.
  """
  def with_exposed_port(%__MODULE__{} = config, port) do
    %__MODULE__{config | exposed_ports: [port | config.exposed_ports]}
  end

  @doc """
  Adds multiple _ports_ to be exposed on the _container_.
  """
  def with_exposed_ports(%__MODULE__{} = config, ports) when is_list(ports) do
    %__MODULE__{config | exposed_ports: ports ++ config.exposed_ports}
  end

  @doc """
  Sets a file or the directory on the _host machine_ to be mounted into a _container_.
  """
  def with_bind_mount(%__MODULE__{} = config, host_src, container_dest, options \\ "ro")
      when is_binary(host_src) and is_binary(container_dest) do
    new_bind_mount = %{host_src: host_src, container_dest: container_dest, options: options}
    %__MODULE__{config | bind_mounts: [new_bind_mount | config.bind_mounts]}
  end

  @doc """
  Sets a label to apply to the container object in docker.
  """
  def with_label(%__MODULE__{} = config, key, value) do
    %__MODULE__{config | labels: Map.put(config.labels, key, value)}
  end

  @doc """
  Gets the host port on the container for the given exposed port.
  """
  def mapped_port(%__MODULE__{} = container, port) when is_number(port) do
    container.exposed_ports
    |> Enum.filter(fn
      %{exposed_port: exposed_port} -> exposed_port == "#{port}/tcp"
      port -> port == "#{port}/tcp"
    end)
    |> List.first(%{})
    |> Map.get(:host_port)
  end

  def run(%__MODULE__{} = container_config, options) do
    on_exit = Keyword.get(options, :on_exit, nil)
    wait_strategies = container_config.wait_strategies || []

    with :ok <- Connection.pull_image(container_config.image),
         {:ok, id} <- Connection.create_container(container_config),
         :ok <- Connection.start_container(id),
         :ok <- if(on_exit, do: on_exit.(fn -> Connection.stop_container(id) end), else: :ok),
         :ok <- Reaper.register({"id", id}),
         :ok <- wait_for_container(id, wait_strategies) do
      Connection.get_container(id)
    end
  end

  defp wait_for_container(id, wait_strategies) when is_binary(id) do
    Enum.reduce(wait_strategies, :ok, fn
      wait_strategy, :ok ->
        WaitStrategy.wait_until_container_is_ready(wait_strategy, id)

      _, error ->
        error
    end)
  end
end
