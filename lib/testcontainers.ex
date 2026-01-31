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

  @doc """
  Starts the Testcontainers application.

  This will terminate when the calling process exits, for ex a task.
  """
  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options, name: Keyword.get(options, :name, __MODULE__))
  end

  @doc """
  Starts the Testcontainers application.

  This will NOT terminate when the calling process exits, for ex a task.
  """
  def start(options \\ []) do
    GenServer.start(__MODULE__, options, name: Keyword.get(options, :name, __MODULE__))
  end

  @impl true
  def init(options \\ []) do
    Process.flag(:trap_exit, true)

    setup(options)
  end

  defp setup(options) do
    {conn, docker_host_url, docker_host} = Connection.get_connection(options)

    # Read testcontainer properties
    {:ok, properties} = PropertiesParser.read_property_sources()

    session_id =
      :crypto.hash(:sha, "#{inspect(self())}#{DateTime.utc_now() |> DateTime.to_string()}")
      |> Base.encode16()

    with {:ok, docker_hostname} <- get_docker_hostname(docker_host_url, conn),
         {:ok, socket} <- start_reaper(conn, session_id, properties, docker_host, docker_hostname),
         {:ok, properties} <- PropertiesParser.read_property_file() do
      Logger.info("Testcontainers initialized")

      {:ok,
       %{
         socket: socket,
         conn: conn,
         docker_hostname: docker_hostname,
         session_id: session_id,
         properties: properties,
         networks: MapSet.new()
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

  @doc """
  Creates a Docker network.

  Networks allow containers to communicate with each other using hostnames.
  Use `Container.with_network/2` to attach a container to a network.

  ## Parameters

  - `network_name`: The name of the network to create.
  - `name`: The name of the Testcontainers GenServer (defaults to `Testcontainers`).

  ## Returns

  - `{:ok, network_id}` if the network is created successfully.
  - `{:ok, :already_exists}` if the network already exists.
  - `{:error, reason}` on failure.
  """
  def create_network(network_name, name \\ __MODULE__) when is_binary(network_name) do
    wait_for_call({:create_network, network_name}, name)
  end

  @doc """
  Removes a Docker network.

  ## Parameters

  - `network_name`: The name of the network to remove.
  - `name`: The name of the Testcontainers GenServer (defaults to `Testcontainers`).

  ## Returns

  - `:ok` if the network is removed successfully.
  - `{:error, reason}` on failure.
  """
  def remove_network(network_name, name \\ __MODULE__) when is_binary(network_name) do
    wait_for_call({:remove_network, network_name}, name)
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

  @impl true
  def handle_call({:create_network, network_name}, from, state) do
    Task.async(fn ->
      result = Api.create_network(network_name, state.conn)
      GenServer.reply(from, result)
    end)

    {:noreply, %{state | networks: MapSet.put(state.networks, network_name)}}
  end

  @impl true
  def handle_call({:remove_network, network_name}, from, state) do
    Task.async(fn ->
      result = Api.remove_network(network_name, state.conn)
      GenServer.reply(from, result)
    end)

    {:noreply, %{state | networks: MapSet.delete(state.networks, network_name)}}
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

  defp start_reaper(conn, session_id, properties, docker_host, docker_hostname) do
    ryuk_disabled = Map.get(properties, "ryuk.disabled", "false") == "true"

    case ryuk_disabled do
      true ->
        ryukDisabledMessage =
          """
          ********************************************************************************
          Ryuk has been disabled. This can cause unexpected behavior in your environment.
          ********************************************************************************
          """

        IO.puts(ryukDisabledMessage)

        {:ok, nil}

      _ ->
        start_ryuk(conn, session_id, properties, docker_host, docker_hostname)
    end
  end

  defp start_ryuk(conn, session_id, properties, docker_host, docker_hostname) do
    ryuk_privileged = Map.get(properties, "ryuk.container.privileged", "false") == "true"

    ryuk_config =
      Container.new("testcontainers/ryuk:#{Constants.ryuk_version()}")
      |> Container.with_exposed_port(8080)
      |> then(&apply_docker_socket_volume_binding(&1, docker_host))
      |> Container.with_auto_remove(true)
      |> Container.with_privileged(ryuk_privileged)

    with {:ok, _} <- Api.pull_image(ryuk_config.image, conn),
         {:ok, ryuk_container_id} <- Api.create_container(ryuk_config, conn),
         :ok <- Api.start_container(ryuk_container_id, conn),
         {:ok, container} <- Api.get_container(ryuk_container_id, conn),
         {:ok, socket} <- create_ryuk_socket(container, docker_hostname),
         :ok <- register_ryuk_filter(session_id, socket) do
      {:ok, socket}
    end
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
    with :ok <- maybe_pull_image(config, state.conn),
         {:ok, id} <- Api.create_container(config, state.conn),
         :ok <- Api.start_container(id, state.conn),
         {:ok, container} <- Api.get_container(id, state.conn),
         :ok <- ContainerBuilder.after_start(config_builder, container, state.conn),
         :ok <- wait_for_container(container, config.wait_strategies || [], state.conn) do
      {:ok, container}
    end
  end

  defp maybe_pull_image(config = %{pull_policy: %{always_pull: true}}, conn) do
    case Api.pull_image(config.image, conn, auth: config.auth) do
      {:ok, _nil} -> :ok
      error -> error
    end
  end

  defp maybe_pull_image(config = %{pull_policy: %{pull_condition: expr}}, conn)
       when is_function(expr) do
    with {:eval, true} <- {:eval, expr.(config, conn)},
         {:ok, _nil} <- Api.pull_image(config.image, conn, auth: config.auth) do
      :ok
    else
      {:eval, reason} ->
        Logger.debug(
          "Pull policy expression evaluated to: #{inspect(reason)}, image will not be fetched"
        )

        :ok

      error ->
        error
    end
  end

  defp maybe_pull_image(_config, _conn) do
    :ok
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
