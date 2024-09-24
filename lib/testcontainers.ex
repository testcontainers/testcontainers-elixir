defmodule Testcontainers do
  use GenServer

  @moduledoc """
  The main entry point into Testcontainers.

  This is a GenServer that needs to be started before anything can happen.
  """

  alias Testcontainers.WaitStrategy
  alias Testcontainers.Logger
  alias Testcontainers.Docker.Api
  alias Testcontainers.Connection
  alias Testcontainers.Container
  alias Testcontainers.ContainerBuilder
  alias Testcontainers.Util.Hash

  import Testcontainers.Constants

  @timeout 300_000

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options, name: Keyword.get(options, :name, __MODULE__))
  end

  @impl true
  def init(options \\ []) do
    Process.flag(:trap_exit, true)

    setup(options)
  end

  defp setup(options) do
    {conn, docker_host_url} = Connection.get_connection(options)

    session_id =
      :crypto.hash(:sha, "#{inspect(self())}#{DateTime.utc_now() |> DateTime.to_string()}")
      |> Base.encode16()

    ryuk_config =
      Container.new("testcontainers/ryuk:0.6.0")
      |> Container.with_exposed_port(8080)
      |> Container.with_environment("RYUK_PORT", "8080")
      |> Container.with_bind_mount("/var/run/docker.sock", "/var/run/docker.sock", "rw")
      |> Container.with_auto_remove(true)

    with {:ok, _} <- Api.pull_image(ryuk_config.image, conn),
         {:ok, ryuk_container_id} <- Api.create_container(ryuk_config, conn),
         :ok <- Api.start_container(ryuk_container_id, conn),
         {:ok, container} <- Api.get_container(ryuk_container_id, conn),
         {:ok, socket} <- create_ryuk_socket(container),
         :ok <- register_ryuk_filter(session_id, socket),
         {:ok, docker_host} <- get_docker_host(docker_host_url, conn) do
      Logger.log("Testcontainers initialized")

      {:ok,
       %{
         socket: socket,
         conn: conn,
         docker_host: docker_host,
         session_id: session_id
       }}
    else
      error ->
        {:stop, error}
    end
  end

  @doc false
  def get_host(name \\ __MODULE__), do: wait_for_call(:get_host, name)

  @doc """
  Starts a new container based on the provided configuration, applying any specified wait strategies.

  This function performs several steps:
  1. Pulls the necessary Docker image.
  2. Creates and starts a container with the specified configuration.
  3. Registers the container with a reaper process for automatic cleanup, ensuring it is stopped and removed when the current process exits or in case of unforeseen failures.

  ## Parameters

  - `config`: A `%Container{}` struct containing the configuration settings for the container, such as the image to use, environment variables, bound ports, and volume bindings.
  ## Examples

      iex> config = Testcontainers.MySqlContainer.new()
      iex> {:ok, container} = Testcontainers.start_container(config)

  ## Returns

  - `{:ok, container}` if the container is successfully created, started, and passes all wait strategies.
  - An error tuple, such as `{:error, reason}`, if there is a failure at any step in the process.

  ## Notes

  - The container is automatically registered with a reaper process, ensuring it is stopped and removed when the current process exits, or in the case of unforeseen failures.
  - It's important to specify appropriate wait strategies to ensure the container is fully ready for interaction, especially for containers that may take some time to start up services internally.

  """
  def start_container(config_builder, name \\ __MODULE__) do
    wait_for_call({:start_container, config_builder}, name)
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
  def stop_container(container_id, name \\ __MODULE__) when is_binary(container_id) do
    wait_for_call({:stop_container, container_id}, name)
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_call({:start_container, config_builder}, from, state) do
    Task.async(fn ->
      GenServer.reply(from, start_and_wait(config_builder, state))
    end)

    {:noreply, state}
  end

  @impl true
  def handle_call({:stop_container, container_id}, from, state) do
    Task.async(fn -> GenServer.reply(from, Api.stop_container(container_id, state.conn)) end)
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_host, _from, state) do
    {:reply, state.docker_host, state}
  end

  # private functions

  defp get_docker_host(docker_host_url, conn) do
    case URI.parse(docker_host_url) do
      uri when uri.scheme == "http" or uri.scheme == "https" ->
        {:ok, uri.host}

      uri when uri.scheme == "http+unix" ->
        if File.exists?("/.dockerenv") do
          Logger.log("Running in docker environment, trying to get bridge network gateway")

          with {:ok, gateway} <- Api.get_bridge_gateway(conn) do
            {:ok, gateway}
          else
            {:error, reason} ->
              Logger.log("Failed to get bridge gateway: #{inspect(reason)}. Using localhost")
              {:ok, "localhost"}
          end
        else
          Logger.log("Not running in docker environment, using localhost")
          {:ok, "localhost"}
        end
    end
  end

  defp wait_for_call(call, name) do
    GenServer.call(name, call, @timeout)
  end

  defp create_ryuk_socket(container, reattempt_count \\ 0)

  defp create_ryuk_socket(%Container{} = container, reattempt_count)
       when reattempt_count < 3 do
    host_port = Container.mapped_port(container, 8080)

    case :gen_tcp.connect(~c"localhost", host_port, [
           :binary,
           active: false,
           packet: :line,
           send_timeout: 10000
         ]) do
      {:ok, connected} ->
        {:ok, connected}

      {:error, :econnrefused} ->
        Logger.log("Connection refused. Retrying... Attempt #{reattempt_count + 1}/3")
        :timer.sleep(5000)
        create_ryuk_socket(container, reattempt_count + 1)

      {:error, error} ->
        {:error, error}
    end
  end

  defp create_ryuk_socket(%Container{} = _container, _reattempt_count) do
    Logger.log("Ryuk host refused to connect")
    {:error, :econnrefused}
  end

  defp register_ryuk_filter(value, socket) do
    :gen_tcp.send(
      socket,
      "label=#{container_sessionId_label()}=#{value}&" <>
        "label=#{container_version_label()}=#{library_version()}&" <>
        "label=#{container_lang_label()}=#{container_lang_value()}&" <>
        "label=#{container_label()}=#{true}\n"
    )

    case :gen_tcp.recv(socket, 0, 2_000) do
      {:ok, "ACK\n"} ->
        :ok

      {:error, reason} ->
        {:error, {:failed_to_register_ryuk_filter, reason}}
    end
  end

  defp start_and_wait(config_builder, state) do
    config =
      ContainerBuilder.build(config_builder)
      |> Container.with_label(container_sessionId_label(), state.session_id)
      |> Container.with_label(container_version_label(), library_version())
      |> Container.with_label(container_lang_label(), container_lang_value())
      |> Container.with_label(container_label(), "#{true}")

    hash = Hash.struct_to_hash(config)
    config = Container.with_label(config, container_hash_label(), hash)

    case Api.get_container_by_hash(hash, state.conn) do
      {:error, :no_container} ->
        Logger.log("Container does not exist with hash: #{hash}")
        with {:ok, _} <- Api.pull_image(config.image, state.conn, auth: config.auth),
             {:ok, id} <- Api.create_container(config, state.conn),
             :ok <- Api.start_container(id, state.conn),
             {:ok, container} <- Api.get_container(id, state.conn),
             :ok <- ContainerBuilder.after_start(config_builder, container, state.conn),
             :ok <- wait_for_container(container, config.wait_strategies || [], state.conn) do
          {:ok, container}
        end

      {:error, error} ->
        Logger.log("Failed to get container by hash: #{inspect(error)}")
        {:error, error}

      {:ok, container} ->
        Logger.log("Container already exists with hash: #{hash}")
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
end
