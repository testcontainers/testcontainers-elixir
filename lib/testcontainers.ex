defmodule Testcontainers do
  use GenServer

  @moduledoc """
  The main entry point into Testcontainers.

  This is a GenServer that needs to be started before anything can happen.
  """

  defstruct []

  alias Testcontainers.WaitStrategy
  alias Testcontainers.Logger
  alias Testcontainers.Docker.Api
  alias Testcontainers.Connection
  alias Testcontainers.Container
  alias Testcontainers.ContainerBuilder

  import Testcontainers.Constants

  @timeout 300_000

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl true
  def init(options \\ []) do
    send(self(), :load)
    {:ok, %{options: options}}
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
  def start_container(config_builder, options \\ []) do
    wait_for_call({:start_container, config_builder, options})
  end

  @doc """
  Stops a running container.

  This sends a stop command to the specified container. The Docker daemon terminates the container process gracefully.

  ## Parameters

  - `container_id`: The ID of the container to stop, as a string.

  ## Returns

  - `:ok` if the container stops successfully.
  - `{:error, reason}` on failure.

  ## Examples

      :ok = Testcontainers.Connection.stop_container("my_container_id")
  """
  def stop_container(container_id) when is_binary(container_id) do
    wait_for_call({:stop_container, container_id})
  end

  @doc """
  Retrieves information about a specific container.

  This can be used to check the status, inspect the configuration, and gather other runtime information about the container.

  ## Parameters

  - `container_id`: The ID of the container, as a string.

  ## Returns

  - `{:ok, %Testcontainers.Container{}}` with detailed information about the container.
  - `{:error, reason}` on failure.

  ## Examples

      {:ok, %Testcontainers.Container{}} = Testcontainers.Connection.get_container("my_container_id")
  """
  def get_container(container_id) when is_binary(container_id) do
    wait_for_call({:get_container, container_id})
  end

  def handle_info(:load, state) do
    conn = Connection.get_connection(state.options)

    session_id =
      :crypto.hash(:sha, "#{inspect(self())}#{DateTime.utc_now() |> DateTime.to_string()}")
      |> Base.encode16()

    ryuk_config = ContainerBuilder.build(%__MODULE__{}, on_exit: nil)

    with {:ok, _} <- Api.pull_image(ryuk_config.image, conn),
         {:ok, id} <- Api.create_container(ryuk_config, conn),
         :ok <- Api.start_container(id, conn),
         {:ok, container} <- Api.get_container(id, conn),
         {:ok, socket} <- create_ryuk_socket(container),
         :ok <- register_ryuk_filter(session_id, socket) do
      Logger.log("Testcontainers initialized")
      {:noreply, %{socket: socket, conn: conn, session_id: session_id}}
    else
      error ->
        {:stop, error, state}
    end
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_call({:start_container, config_builder, options}, from, state) do
    Task.async(fn ->
      GenServer.reply(from, start_and_wait(config_builder, options, state))
    end)

    {:noreply, state}
  end

  @impl true
  def handle_call({:stop_container, container_id}, from, state) do
    Task.async(fn -> GenServer.reply(from, Api.stop_container(container_id, state.conn)) end)
    {:noreply, state}
  end

  @impl true
  def handle_call({:get_container, container_id}, from, state) do
    Task.async(fn -> GenServer.reply(from, Api.get_container(container_id, state.conn)) end)
    {:noreply, state}
  end

  # private functions

  defp wait_for_call(call) do
    GenServer.call(__MODULE__, call, @timeout)
  end

  defp create_ryuk_socket(%Container{} = container) do
    host_port = Container.mapped_port(container, 8080)

    :gen_tcp.connect(~c"localhost", host_port, [
      :binary,
      active: false,
      packet: :line
    ])
  end

  defp register_ryuk_filter(value, socket) do
    :gen_tcp.send(
      socket,
      "label=#{container_sessionId_label()}=#{value}&" <>
        "label=#{container_version_label()}=#{library_version()}&" <>
        "label=#{container_lang_label()}=#{container_lang_value()}&" <>
        "label=#{container_label()}=#{true}\n"
    )

    case :gen_tcp.recv(socket, 0, 1_000) do
      {:ok, "ACK\n"} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp start_and_wait(config_builder, options, state) do
    config = ContainerBuilder.build(config_builder, options)
    wait_strategies = config.wait_strategies || []

    with {:ok, _} <- Api.pull_image(config.image, state.conn),
         {:ok, id} <-
           Api.create_container(
             config
             |> Container.with_label(container_sessionId_label(), state.session_id)
             |> Container.with_label(container_version_label(), library_version())
             |> Container.with_label(container_lang_label(), container_lang_value())
             |> Container.with_label(container_label(), "#{true}"),
             state.conn
           ),
         :ok <- Api.start_container(id, state.conn),
         {:ok, container} <- Api.get_container(id, state.conn),
         :ok <- wait_for_container(container, wait_strategies, state.conn) do
      {:ok, container}
    end
  end

  defp wait_for_container(container, wait_strategies, conn) do
    Enum.reduce(wait_strategies, :ok, fn
      wait_strategy, :ok ->
        WaitStrategy.wait_until_container_is_ready(wait_strategy, container, conn)

      _, error ->
        error
    end)
  end

  defimpl ContainerBuilder do
    @spec build(%Testcontainers{}, keyword()) :: %Container{}
    @impl true
    def build(_, _) do
      Container.new("testcontainers/ryuk:0.5.1")
      |> Container.with_exposed_port(8080)
      |> Container.with_environment("RYUK_PORT", "8080")
      |> Container.with_bind_mount("/var/run/docker.sock", "/var/run/docker.sock", "rw")
    end
  end
end
