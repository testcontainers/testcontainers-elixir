defmodule Testcontainers do
  use GenServer

  @moduledoc """
  The main entry point into Testcontainers.

  This is a GenServer that needs to be started before anything can happen.
  """

  require Logger

  alias Testcontainers.Constants
  alias Testcontainers.WaitStrategy
  alias Testcontainers.Docker.Api
  alias Testcontainers.Connection
  alias Testcontainers.Container
  alias Testcontainers.ContainerBuilder
  alias Testcontainers.Util.PropertiesParser

  import Testcontainers.Constants
  import Testcontainers.Container, only: [os_type: 0]

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
    {conn, docker_host_url, docker_host} = Connection.get_connection(options)

    session_id =
      :crypto.hash(:sha, "#{inspect(self())}#{DateTime.utc_now() |> DateTime.to_string()}")
      |> Base.encode16()

    ryuk_config =
      Container.new("testcontainers/ryuk:#{Constants.ryuk_version()}")
      |> Container.with_exposed_port(8080)
      |> then(&apply_docker_socket_volume_binding(&1, docker_host))
      |> Container.with_auto_remove(false)
      |> Container.with_privileged(true)

    with {:ok, _} <- Api.pull_image(ryuk_config.image, conn),
         {:ok, docker_hostname} <- get_docker_hostname(docker_host_url, conn),
         {:ok, ryuk_container_id} <- Api.create_container(ryuk_config, conn),
         :ok <- Api.start_container(ryuk_container_id, conn),
         {:ok, container} <- Api.get_container(ryuk_container_id, conn),
         {:ok, socket} <- create_ryuk_socket(container, docker_hostname),
         :ok <- register_ryuk_filter(session_id, socket),
         {:ok, properties} <- PropertiesParser.read_property_file() do
      Logger.info("Testcontainers initialized")

      {:ok,
       %{
         socket: socket,
         conn: conn,
         docker_hostname: docker_hostname,
         session_id: session_id,
         properties: properties
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
    {:reply, state.docker_hostname, state}
  end

  # private functions

  defp get_docker_hostname(docker_host_url, conn) do
    case URI.parse(docker_host_url) do
      uri when uri.scheme == "http" or uri.scheme == "https" ->
        {:ok, uri.host}

      uri when uri.scheme == "http+unix" ->
        if File.exists?("/.dockerenv") do
          Logger.debug("Running in docker environment, trying to get bridge network gateway")

          with {:ok, gateway} <- Api.get_bridge_gateway(conn) do
            {:ok, gateway}
          else
            {:error, reason} ->
              Logger.debug("Failed to get bridge gateway: #{inspect(reason)}. Using localhost")
              {:ok, "localhost"}
          end
        else
          Logger.debug("Not running in docker environment, using localhost")
          {:ok, "localhost"}
        end
    end
  end

  defp wait_for_call(call, name) do
    GenServer.call(name, call, @timeout)
  end

  defp create_ryuk_socket(container, docker_hostname, reattempt_count \\ 0)

  defp create_ryuk_socket(%Container{} = container, docker_hostname, reattempt_count)
       when reattempt_count < 3 do
    host_port = Container.mapped_port(container, 8080)

    case :gen_tcp.connect(~c"#{docker_hostname}", host_port, [
           :binary,
           active: false,
           packet: :line,
           send_timeout: 10000
         ]) do
      {:ok, connected} ->
        {:ok, connected}

      {:error, :econnrefused} ->
        Logger.info("Connection refused. Retrying... Attempt #{reattempt_count + 1}/3")
        :timer.sleep(5000)
        create_ryuk_socket(container, docker_hostname, reattempt_count + 1)

      {:error, error} ->
        {:error, error}
    end
  end

  defp create_ryuk_socket(%Container{} = _container, _docker_hostname, _reattempt_count) do
    Logger.info("Ryuk host refused to connect")
    {:error, :econnrefused}
  end

  defp register_ryuk_filter(value, socket) do
    :gen_tcp.send(
      socket,
      "label=#{container_sessionId_label()}=#{value}&" <>
        "label=#{container_version_label()}=#{library_version()}&" <>
        "label=#{container_lang_label()}=#{container_lang_value()}&" <>
        "label=#{container_label()}=#{true}&" <>
        "label=#{container_reuse()}=#{false}\n"
    )

    case :gen_tcp.recv(socket, 0, 2_000) do
      {:ok, "ACK\n"} ->
        :ok

      {:error, reason} ->
        {:error, {:failed_to_register_ryuk_filter, reason}}
    end
  end

  defp start_and_wait(config_builder, state) do
    case Testcontainers.ContainerBuilderHelper.build(config_builder, state) do
      {:reuse, config, hash} ->
        case Api.get_container_by_hash(hash, state.conn) do
          {:error, :no_container} ->
            Logger.debug("Container does not exist with hash: #{hash}")

            create_and_start_container(
              config,
              config_builder,
              state
            )

          {:error, error} ->
            Logger.debug("Failed to get container by hash: #{inspect(error)}")
            {:error, error}

          {:ok, container} ->
            Logger.debug("Container already exists with hash: #{hash}")
            {:ok, container}
        end

      {:noreuse, config, _} ->
        create_and_start_container(
          config,
          config_builder,
          state
        )
    end
  end

  defp create_and_start_container(config, config_builder, state) do
    with {:ok, _} <- Api.pull_image(config.image, state.conn, auth: config.auth),
         {:ok, id} <- Api.create_container(config, state.conn),
         :ok <- Api.start_container(id, state.conn),
         {:ok, container} <- Api.get_container(id, state.conn),
         :ok <- ContainerBuilder.after_start(config_builder, container, state.conn),
         :ok <- wait_for_container(container, config.wait_strategies || [], state.conn) do
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

  defp apply_docker_socket_volume_binding(config, docker_host) do
    case {os_type(), URI.parse(docker_host)} do
      {os, uri} -> handle_docker_socket_binding(config, os, uri)
    end
  end

  @dialyzer {:nowarn_function, handle_docker_socket_binding: 3}
  defp handle_docker_socket_binding(config, :linux, %URI{scheme: "unix", path: docker_socket_path}) do
    Container.with_bind_mount(
      config,
      docker_socket_path,
      "/var/run/docker.sock",
      "rw"
    )
  end

  defp handle_docker_socket_binding(config, :macos, %URI{scheme: "unix", path: docker_socket_path}) do
    Container.with_bind_mount(
      config,
      docker_socket_path,
      "/var/run/docker.sock",
      "rw"
    )
  end

  defp handle_docker_socket_binding(config, :windows, _) do
    Container.with_bind_mount(
      config,
      "//var/run/docker.sock",
      "/var/run/docker.sock",
      "rw"
    )
  end

  defp handle_docker_socket_binding(config, _, _), do: config
end
