defmodule Testcontainers do
  use GenServer

  defstruct []

  alias Testcontainers.Docker.Api
  alias Testcontainers.Connection
  alias Testcontainers.Container
  alias Testcontainers.ContainerBuilder

  @ryuk_filter_label "testcontainers-elixir-reap"
  @timeout 300_000

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl true
  def init(options \\ []) do
    conn = Connection.get_connection(options)

    session_id =
      :crypto.hash(:sha, "#{inspect(self())}#{DateTime.utc_now() |> DateTime.to_string()}")
      |> Base.encode16()

    ryuk_config = ContainerBuilder.build(%__MODULE__{}, on_exit: nil)

    with :ok <- Api.pull_image(ryuk_config.image, conn),
         {:ok, id} <- Api.create_container(ryuk_config, conn),
         :ok <- Api.start_container(id, conn),
         {:ok, container} <- Api.get_container(id, conn),
         {:ok, socket} <- create_ryuk_socket(container),
         :ok <- register("label", @ryuk_filter_label, session_id, socket) do
      Testcontainers.Utils.log("Testcontainers initialized")
      {:ok, %{socket: socket, container: container, conn: conn, session_id: session_id}}
    end
  end

  def register(type, key, value, socket) do
    :gen_tcp.send(
      socket,
      "#{:uri_string.quote(type)}=#{:uri_string.quote(key)}=#{:uri_string.quote(value)}" <> "\n"
    )

    case :gen_tcp.recv(socket, 0, 1_000) do
      {:ok, "ACK\n"} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
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

  defp create_ryuk_socket(%Container{} = container) do
    host_port = Container.mapped_port(container, 8080)

    :gen_tcp.connect(~c"localhost", host_port, [
      :binary,
      active: false,
      packet: :line
    ])
  end

  @doc """
  Pulls a Docker image.

  This function sends a request to the Docker daemon to pull an image from a Docker registry. If the image already exists locally, it will be skipped.

  ## Parameters

  - `image`: A string representing the Docker image tag.

  ## Examples

      :ok = Testcontainers.Connection.pull_image("nginx:latest")

  ## Returns

  - `:ok` if the image is successfully pulled.
  - `{:error, reason}` if there is a failure to pull the image.

  ## Notes

  - This function requires that the Docker daemon is running and accessible.
  - Network issues or invalid image tags can cause failures.
  """
  def pull_image(image) when is_binary(image) do
    GenServer.call(__MODULE__, {:pull_image, image}, @timeout)
  end

  @doc """
  Creates a Docker container based on the specified configuration.

  The container is not started automatically. Use `start_container/1` to run it.

  ## Parameters

  - `container`: A `%Container{}` struct containing the configuration for the new Docker container.

  ## Returns

  - `{:ok, container_id}` if the container is successfully created.
  - `{:error, reason}` on failure.

  ## Examples

      config = %Container{image: "nginx:latest"}
      {:ok, container_id} = Testcontainers.Connection.create_container(config)
  """
  def create_container(%Container{} = container) do
    GenServer.call(__MODULE__, {:create_container, container}, @timeout)
  end

  @doc """
  Starts a previously created Docker container.

  Requires the container ID of a container that has been created but not yet started.

  ## Parameters

  - `container_id`: The ID of the container to start, as a string.

  ## Returns

  - `:ok` if the container starts successfully.
  - `{:error, reason}` on failure.

  ## Examples

      :ok = Testcontainers.Connection.start_container("my_container_id")
  """
  def start_container(container_id) when is_binary(container_id) do
    GenServer.call(__MODULE__, {:start_container, container_id}, @timeout)
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
    GenServer.call(__MODULE__, {:stop_container, container_id}, @timeout)
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
    GenServer.call(__MODULE__, {:get_container, container_id}, @timeout)
  end

  @doc """
  Retrieves the stdout logs from a specified container.

  Useful for debugging and monitoring, this function collects the logs that have been written to stdout within the container.

  ## Parameters

  - `container_id`: The ID of the container, as a string.

  ## Returns

  - `{:ok, logs}` where `logs` is the content that has been written to stdout in the container.
  - `{:error, reason}` on failure.

  ## Examples

      {:ok, logs} = Testcontainers.Connection.stdout_logs("my_container_id")
  """
  def stdout_logs(container_id) when is_binary(container_id) do
    GenServer.call(__MODULE__, {:stdout_logs, container_id}, @timeout)
  end

  @doc """
  Creates a new execution context in a running container and runs the specified command.

  This function is used to execute a one-off command within the context of the container.

  ## Parameters

  - `container_id`: The ID of the container, as a string.
  - `command`: A list of strings representing the command and its arguments to run in the container.

  ## Returns

  - `{:ok, exec_id}` which is an identifier for the executed command, useful for further inspection or interaction.
  - `{:error, reason}` on failure.

  ## Examples

      {:ok, exec_id} = Testcontainers.Connection.exec_create("my_container_id", ["ls", "-la"])
  """
  def exec_create(container_id, command) when is_binary(container_id) and is_list(command) do
    GenServer.call(__MODULE__, {:exec_create, command, container_id}, @timeout)
  end

  @doc """
  Initiates the execution of a previously created command in a running container.

  This function is used after `exec_create/2` to start the execution of the command within the container context.

  ## Parameters

  - `exec_id`: A string representing the unique identifier of the command to be executed (obtained from `exec_create/2`).

  ## Returns

  - `:ok` if the command execution started successfully.
  - `{:error, reason}` on failure.

  ## Examples

      :ok = Testcontainers.Connection.exec_start("my_exec_id")
  """
  def exec_start(exec_id) when is_binary(exec_id) do
    GenServer.call(__MODULE__, {:exec_start, exec_id}, @timeout)
  end

  @doc """
  Retrieves detailed information about a specific exec command.

  It's particularly useful for obtaining the exit status and other related data after a command has been executed in a container.

  ## Parameters

  - `exec_id`: A string representing the unique identifier of the executed command (obtained from `exec_create/2`).

  ## Returns

  - `{:ok, %{running: _, exit_code: _}}` with information about running state and exit code.
  - `{:error, reason}` on failure.

  ## Examples

      {:ok, exec_info} = Testcontainers.Connection.exec_inspect("my_exec_id")
  """
  def exec_inspect(exec_id) when is_binary(exec_id) do
    GenServer.call(__MODULE__, {:exec_inspect, exec_id}, @timeout)
  end

  @impl true
  def handle_call({:pull_image, image}, _from, %{conn: conn} = state) do
    {:reply, Api.pull_image(image, conn), state}
  end

  @impl true
  def handle_call({:get_container, container_id}, _from, %{conn: conn} = state) do
    {:reply, Api.get_container(container_id, conn), state}
  end

  @impl true
  def handle_call({:start_container, container_id}, _from, %{conn: conn} = state) do
    {:reply, Api.start_container(container_id, conn), state}
  end

  @impl true
  def handle_call(
        {:create_container, %Container{} = container},
        _from,
        %{conn: conn, session_id: session_id} = state
      ) do
    {:reply,
     Api.create_container(
       container |> Container.with_label(@ryuk_filter_label, session_id),
       conn
     ), state}
  end

  @impl true
  def handle_call({:stop_container, container_id}, _from, %{conn: conn} = state) do
    {:reply, Api.stop_container(container_id, conn), state}
  end

  @impl true
  def handle_call({:stdout_logs, container_id}, _from, %{conn: conn} = state) do
    {:reply, Api.stdout_logs(container_id, conn), state}
  end

  @impl true
  def handle_call({:exec_create, command, container_id}, _from, %{conn: conn} = state) do
    {:reply, Api.create_exec(container_id, command, conn), state}
  end

  @impl true
  def handle_call({:exec_start, exec_id}, _from, %{conn: conn} = state) do
    {:reply, Api.start_exec(exec_id, conn), state}
  end

  @impl true
  def handle_call({:exec_inspect, exec_id}, _from, %{conn: conn} = state) do
    {:reply, Api.inspect_exec(exec_id, conn), state}
  end
end
