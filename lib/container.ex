# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule Testcontainers.Container do
  alias Testcontainers.Container
  alias Testcontainers.ContainerBuilder
  alias Testcontainers.WaitStrategy

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
  def with_environment(%__MODULE__{} = config, key, value)
      when (is_binary(key) or is_atom(key)) and is_binary(value) do
    %__MODULE__{config | environment: Map.put(config.environment, key, value)}
  end

  @doc """
  Adds a _port_ to be exposed on the _container_.
  """
  def with_exposed_port(%__MODULE__{} = config, port) when is_integer(port) do
    filtered_ports = config.exposed_ports |> Enum.reject(fn p -> p == port end)

    %__MODULE__{config | exposed_ports: [port | filtered_ports]}
  end

  def with_fixed_port(%__MODULE__{} = config, port, host_port \\ nil)
      when is_integer(port) and (is_nil(host_port) or is_integer(host_port)) do
    filtered_ports = config.exposed_ports |> Enum.reject(fn p -> p == port end)

    %__MODULE__{
      config
      | exposed_ports: [
          {port, host_port || port} | filtered_ports
        ]
    }
  end

  @doc """
  Adds multiple _ports_ to be exposed on the _container_.
  """
  def with_exposed_ports(%__MODULE__{} = config, ports) when is_list(ports) do
    filtered_ports = config.exposed_ports |> Enum.reject(fn port -> port in ports end)

    %__MODULE__{config | exposed_ports: ports ++ filtered_ports}
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
  def with_label(%__MODULE__{} = config, key, value) when is_binary(key) and is_binary(value) do
    %__MODULE__{config | labels: Map.put(config.labels, key, value)}
  end

  @doc """
  Gets the host port on the container for the given exposed port.
  """
  def mapped_port(%__MODULE__{} = container, port) when is_number(port) do
    container.exposed_ports
    |> Enum.filter(fn
      {exposed_port, _} -> exposed_port == port
      port -> port == port
    end)
    |> List.first({})
    |> Tuple.to_list()
    |> List.last()
  end

  @doc """
  Starts a new container based on the provided configuration, applying any specified wait strategies.

  This function performs several steps:
  1. Pulls the necessary Docker image.
  2. Creates and starts a container with the specified configuration.
  3. Registers the container with a reaper process for automatic cleanup, ensuring it is stopped and removed when the current process exits or in case of unforeseen failures.

  ## Parameters

  - `config`: A `%Container{}` struct containing the configuration settings for the container, such as the image to use, environment variables, bound ports, and volume bindings.
  - `options`: Optional keyword list. Supports the following options:
    - `:on_exit`: A callback function that's invoked when the current process exits. It receives a no-argument callable (often a lambda) that executes cleanup actions, such as stopping the container. This callback enhances the reaper's functionality by providing immediate cleanup actions at the process level, while the reaper ensures that containers are ultimately cleaned up in situations like abrupt process termination. It's especially valuable in test environments, complementing ExUnit's `on_exit` for resource cleanup after tests.

  ## Examples

      iex> config = %Container{
            image: "mysql:latest",
            wait_strategies: [CommandWaitStrategy.new(["bash", "sh", "command_that_returns_0_exit_code"])]
          }
      iex> {:ok, container} = Container.run(config)

  ## Returns

  - `{:ok, container}` if the container is successfully created, started, and passes all wait strategies.
  - An error tuple, such as `{:error, reason}`, if there is a failure at any step in the process.

  ## Notes

  - The container is automatically registered with a reaper process, ensuring it is stopped and removed when the current process exits, or in the case of unforeseen failures.
  - It's important to specify appropriate wait strategies to ensure the container is fully ready for interaction, especially for containers that may take some time to start up services internally.

  """
  @spec run(ContainerBuilder.t(), keyword()) ::
          {:ok, %Container{}} | {:error, any()}
  def run(config_builder, options \\ []) do
    on_exit = Keyword.get(options, :on_exit, nil)
    config = ContainerBuilder.build(config_builder, options)
    wait_strategies = config.wait_strategies || []

    with :ok <- Testcontainers.pull_image(config.image),
         {:ok, id} <- Testcontainers.create_container(config),
         :ok <- Testcontainers.start_container(id),
         :ok <-
           if(on_exit,
             do: on_exit.(fn -> Testcontainers.stop_container(id) end),
             else: :ok
           ),
         :ok <- wait_for_container(id, wait_strategies) do
      Testcontainers.get_container(id)
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

defprotocol Testcontainers.ContainerBuilder do
  @spec build(t(), keyword()) :: %Testcontainers.Container{}
  def build(builder, options)
end
