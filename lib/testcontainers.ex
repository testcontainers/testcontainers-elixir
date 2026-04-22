defmodule Testcontainers do
  use GenServer

  @moduledoc """
  The main entry point into Testcontainers.

  This is a GenServer that needs to be started before anything can happen.
  """

  require Logger

  alias Testcontainers.Compose.Cli, as: ComposeCli
  alias Testcontainers.Compose.ComposeEnvironment
  alias Testcontainers.Compose.ComposeService
  alias Testcontainers.Connection
  alias Testcontainers.Constants
  alias Testcontainers.Container
  alias Testcontainers.ContainerBuilder
  alias Testcontainers.CopyTo
  alias Testcontainers.Docker.Api
  alias Testcontainers.Docker.Auth, as: DockerAuth
  alias Testcontainers.DockerCompose
  alias Testcontainers.PullPolicy
  alias Testcontainers.Util.PropertiesParser
  alias Testcontainers.WaitStrategy

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

    with {:ok, docker_hostname} <- get_docker_hostname(docker_host_url, conn, properties),
         use_container_ip <- should_use_container_ip?(docker_hostname),
         {:ok} <- start_reaper(conn, session_id, properties, docker_host, docker_hostname) do
      if use_container_ip do
        Logger.info(
          "Testcontainers initialized in container networking mode " <>
            "(using container IPs directly)"
        )
      else
        Logger.info("Testcontainers initialized")
      end

      {:ok,
       %{
         conn: conn,
         docker_hostname: docker_hostname,
         use_container_ip: use_container_ip,
         session_id: session_id,
         properties: properties,
         networks: MapSet.new(),
         containers: MapSet.new(),
         images: MapSet.new(),
         compose_envs: []
       }}
    else
      error ->
        {:stop, error}
    end
  end

  @doc false
  def get_host, do: wait_for_call(:get_host, __MODULE__)

  @doc """
  Returns the host to use for connecting to the given container.

  In standard mode, returns the same as `get_host/0` (the Docker host).
  In container networking mode (DooD), returns the container's internal IP
  since mapped ports on the bridge gateway may be unreachable.
  """
  def get_host(%Container{} = container), do: get_host(container, __MODULE__)
  def get_host(name) when is_atom(name), do: wait_for_call(:get_host, name)

  def get_host(%Container{} = container, name) do
    if use_container_ip?(container, name) do
      container.ip_address
    else
      wait_for_call(:get_host, name)
    end
  end

  @doc """
  Returns the port to use for connecting to the given container on the specified internal port.

  In standard mode, returns the host-mapped port (same as `Container.mapped_port/2`).
  In container networking mode (DooD), returns the internal port directly
  since we connect to the container's IP on the bridge network.
  """
  def get_port(%Container{} = container, port), do: get_port(container, port, __MODULE__)

  def get_port(%Container{} = container, port, name) do
    if use_container_ip?(container, name) do
      port
    else
      Container.mapped_port(container, port)
    end
  end

  # Returns true when we should use the container's internal IP and port.
  # Only applies when in container_ip mode AND the container is on the default
  # bridge network. Containers on custom networks are not reachable from the
  # test container via internal IP.
  defp use_container_ip?(%Container{} = container, name) do
    case wait_for_call(:get_connection_mode, name) do
      :container_ip ->
        is_binary(container.ip_address) and container.ip_address != "" and
          is_nil(container.network)

      _ ->
        false
    end
  end

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
  Starts a Docker Compose environment based on the provided configuration.

  ## Parameters

  - `config`: A `%DockerCompose{}` struct containing the configuration.

  ## Returns

  - `{:ok, compose_env}` if the compose environment starts successfully.
  - `{:error, reason}` on failure.
  """
  def start_compose(config, name \\ __MODULE__) do
    wait_for_call({:start_compose, config}, name)
  end

  @doc """
  Stops a running Docker Compose environment.

  ## Parameters

  - `compose_env`: A `%ComposeEnvironment{}` struct representing the running environment.

  ## Returns

  - `:ok` if the compose environment stops successfully.
  - `{:error, reason}` on failure.
  """
  def stop_compose(compose_env, name \\ __MODULE__) do
    wait_for_call({:stop_compose, compose_env}, name)
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
  def handle_cast({:track_container, container_id, image}, state) do
    {:noreply,
     %{
       state
       | containers: MapSet.put(state.containers, container_id),
         images: MapSet.put(state.images, image)
     }}
  end

  def handle_cast({:track_image, image}, state) do
    {:noreply, %{state | images: MapSet.put(state.images, image)}}
  end

  def handle_cast({:track_compose_env, compose_env}, state) do
    {:noreply, %{state | compose_envs: [compose_env | state.compose_envs]}}
  end

  def handle_cast({:untrack_compose_env, compose_env}, state) do
    updated =
      Enum.reject(state.compose_envs, fn env ->
        env.project_name == compose_env.project_name
      end)

    {:noreply, %{state | compose_envs: updated}}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    for compose_env <- Map.get(state, :compose_envs, []) do
      Logger.info("Stopping compose environment #{compose_env.project_name}")
      ComposeCli.down(compose_env.compose)
    end

    for container_id <- state.containers do
      Logger.info("Terminating container #{container_id}")
      Api.stop_container(container_id, state.conn)
    end

    for network <- state.networks do
      Logger.info("Removing network #{network}")
      Api.remove_network(network, state.conn)
    end

    if Map.get(state.properties, "cleanup.images", "false") == "true" do
      for image <- state.images do
        Logger.info("Removing image #{image}")
        Api.delete_image(image, state.conn)
      end
    end

    :ok
  end

  @impl true
  def handle_call({:start_container, config_builder}, from, state) do
    self_pid = self()

    Task.async(fn ->
      result = start_and_wait(config_builder, state)
      track_result(self_pid, config_builder, result)
      GenServer.reply(from, result)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_call({:stop_container, container_id}, from, state) do
    Task.async(fn -> GenServer.reply(from, Api.stop_container(container_id, state.conn)) end)
    {:noreply, %{state | containers: MapSet.delete(state.containers, container_id)}}
  end

  @impl true
  def handle_call(:get_host, _from, state) do
    {:reply, state.docker_hostname, state}
  end

  @impl true
  def handle_call(:get_connection_mode, _from, state) do
    mode = if state.use_container_ip, do: :container_ip, else: :mapped_port
    {:reply, mode, state}
  end

  @impl true
  def handle_call({:create_network, network_name}, from, state) do
    labels = %{
      Constants.container_session_id_label() => state.session_id,
      Constants.container_version_label() => Constants.library_version(),
      Constants.container_lang_label() => Constants.container_lang_value(),
      Constants.container_label() => "true",
      Constants.container_reuse() => "false"
    }

    Task.async(fn ->
      result = Api.create_network(network_name, state.conn, labels: labels)
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

  @impl true
  def handle_call({:start_compose, %DockerCompose{} = compose}, from, state) do
    self_pid = self()

    Task.async(fn ->
      result = start_compose_env(compose, state)

      case result do
        {:ok, compose_env} ->
          GenServer.cast(self_pid, {:track_compose_env, compose_env})

        _ ->
          :ok
      end

      GenServer.reply(from, result)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_call({:stop_compose, %ComposeEnvironment{} = compose_env}, from, state) do
    self_pid = self()

    Task.async(fn ->
      result = ComposeCli.down(compose_env.compose)
      GenServer.cast(self_pid, {:untrack_compose_env, compose_env})
      GenServer.reply(from, result)
    end)

    {:noreply, state}
  end

  # private functions

  defp should_use_container_ip?(docker_hostname) do
    if running_in_container?() and docker_hostname != "localhost" do
      # Probe the bridge gateway to check if mapped ports are reachable.
      # If hairpin NAT is blocked (common in DooD), we fall back to
      # connecting to containers via their internal IPs.
      case :gen_tcp.connect(~c"#{docker_hostname}", 0, [], 2000) do
        {:ok, socket} ->
          :gen_tcp.close(socket)
          false

        {:error, :econnrefused} ->
          # Connection refused means the host IS reachable, just no service on port 0
          false

        {:error, reason} ->
          Logger.info(
            "Bridge gateway #{docker_hostname} unreachable (#{inspect(reason)}). " <>
              "Switching to container networking mode (direct IP access)"
          )

          true
      end
    else
      false
    end
  end

  @doc false
  def running_in_container?(
        dockerenv_path \\ "/.dockerenv",
        cgroup_path \\ "/proc/1/cgroup"
      ) do
    if File.exists?(dockerenv_path) do
      true
    else
      case File.read(cgroup_path) do
        {:ok, content} ->
          Regex.match?(~r/(docker|kubepods|lxc|containerd)/, content)

        {:error, _} ->
          false
      end
    end
  end

  defp start_compose_env(%DockerCompose{} = compose, state) do
    with :ok <- ComposeCli.up(compose),
         {:ok, ps_entries} <- ComposeCli.ps(compose) do
      services =
        ps_entries
        |> Enum.map(fn entry ->
          service_name = Map.get(entry, "Service", "")
          container_id = Map.get(entry, "ID", "")
          service_state = Map.get(entry, "State", "")
          publishers = Map.get(entry, "Publishers", [])
          ports = ComposeCli.parse_publishers(publishers)

          %ComposeService{
            service_name: service_name,
            container_id: container_id,
            state: service_state,
            exposed_ports: ports
          }
        end)
        |> Map.new(fn service -> {service.service_name, service} end)

      # Run per-service wait strategies if configured
      with :ok <- run_compose_wait_strategies(compose, services, state) do
        compose_env = %ComposeEnvironment{
          compose: compose,
          project_name: compose.project_name,
          docker_host: state.docker_hostname,
          services: services
        }

        {:ok, compose_env}
      end
    end
  end

  @doc false
  def parse_gateway_from_proc_route(content) do
    content
    |> String.split("\n")
    |> Enum.drop(1)
    |> Enum.map(&String.split(&1, "\t"))
    |> Enum.find(fn
      [_iface, destination | _rest] -> destination == "00000000"
      _ -> false
    end)
    |> case do
      [_iface, _destination, gateway_hex | _rest] ->
        decode_hex_gateway(gateway_hex)

      _ ->
        {:error, :no_default_route}
    end
  end

  defp decode_hex_gateway(hex) when byte_size(hex) == 8 do
    {value, ""} = Integer.parse(hex, 16)

    a = Bitwise.band(value, 0xFF)
    b = Bitwise.band(Bitwise.bsr(value, 8), 0xFF)
    c = Bitwise.band(Bitwise.bsr(value, 16), 0xFF)
    d = Bitwise.band(Bitwise.bsr(value, 24), 0xFF)

    {:ok, "#{a}.#{b}.#{c}.#{d}"}
  end

  defp decode_hex_gateway(_), do: {:error, :invalid_gateway}

  defp run_compose_wait_strategies(%DockerCompose{} = compose, services, state) do
    Enum.reduce_while(compose.wait_strategies, :ok, fn {service_name, strategies}, :ok ->
      run_service_wait_strategies(service_name, strategies, services, state)
    end)
  end

  defp run_service_wait_strategies(service_name, strategies, services, state) do
    case Map.get(services, service_name) do
      nil ->
        {:halt, {:error, {:service_not_found, service_name}}}

      %ComposeService{container_id: container_id} ->
        apply_wait_strategies_to_container(container_id, strategies, state)
    end
  end

  defp apply_wait_strategies_to_container(container_id, strategies, state) do
    case Api.get_container(container_id, state.conn) do
      {:ok, container} ->
        case reduce_wait_strategies(strategies, container, state) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end

      {:error, _} = error ->
        {:halt, error}
    end
  end

  defp reduce_wait_strategies(strategies, container, state) do
    Enum.reduce(strategies, :ok, fn
      strategy, :ok ->
        WaitStrategy.wait_until_container_is_ready(strategy, container, state.conn)

      _, error ->
        error
    end)
  end

  defp get_docker_hostname(docker_host_url, conn, properties) do
    # Check for explicit host override first
    host_override =
      Map.get(properties, "tc.host.override") ||
        System.get_env("TESTCONTAINERS_HOST_OVERRIDE")

    if host_override do
      Logger.debug("Using host override: #{host_override}")
      {:ok, host_override}
    else
      do_get_docker_hostname(docker_host_url, conn)
    end
  end

  defp do_get_docker_hostname(docker_host_url, conn) do
    case URI.parse(docker_host_url) do
      uri when uri.scheme == "http" or uri.scheme == "https" ->
        {:ok, uri.host}

      uri when uri.scheme == "http+unix" ->
        resolve_unix_docker_hostname(conn)
    end
  end

  defp resolve_unix_docker_hostname(conn) do
    if running_in_container?() do
      Logger.debug("Running in docker environment, trying to get bridge network gateway")
      resolve_bridge_gateway(conn)
    else
      Logger.debug("Not running in docker environment, using localhost")
      {:ok, "localhost"}
    end
  end

  defp resolve_bridge_gateway(conn) do
    case Api.get_bridge_gateway(conn) do
      {:ok, gateway} ->
        {:ok, gateway}

      {:error, reason} ->
        Logger.debug("Failed to get bridge gateway: #{inspect(reason)}. Trying /proc/net/route")
        resolve_gateway_from_proc_route()
    end
  end

  defp resolve_gateway_from_proc_route do
    case File.read("/proc/net/route") do
      {:ok, content} ->
        resolve_gateway_from_content(content)

      {:error, _} ->
        Logger.debug("Cannot read /proc/net/route. Using localhost")
        {:ok, "localhost"}
    end
  end

  defp resolve_gateway_from_content(content) do
    case parse_gateway_from_proc_route(content) do
      {:ok, gateway} ->
        Logger.debug("Found gateway from /proc/net/route: #{gateway}")
        {:ok, gateway}

      {:error, _} ->
        Logger.debug("Failed to parse /proc/net/route. Using localhost")
        {:ok, "localhost"}
    end
  end

  defp wait_for_call(call, name) do
    GenServer.call(name, call, @timeout)
  end

  defp start_reaper(conn, session_id, properties, docker_host, docker_hostname) do
    ryuk_disabled = Map.get(properties, "ryuk.disabled", "false") == "true"

    case ryuk_disabled do
      true ->
        ryuk_disabled_message =
          """
          ********************************************************************************
          Ryuk has been disabled. This can cause unexpected behavior in your environment.
          ********************************************************************************
          """

        IO.puts(ryuk_disabled_message)

        {:ok}

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

    ryuk_config = resolve_pull_policy(ryuk_config, properties)

    with :ok <- maybe_pull_image(ryuk_config, conn),
         {:ok, ryuk_container_id} <- Api.create_container(ryuk_config, conn),
         :ok <- Api.start_container(ryuk_container_id, conn),
         {:ok, container} <- Api.get_container(ryuk_container_id, conn),
         :ok <- connect_and_register_ryuk(container, docker_hostname, session_id) do
      {:ok}
    end
  end

  defp connect_and_register_ryuk(container, docker_hostname, session_id, attempt \\ 1)

  defp connect_and_register_ryuk(container, docker_hostname, session_id, attempt)
       when attempt <= 5 do
    with {:ok, socket} <- create_ryuk_socket(container, docker_hostname),
         :ok <- register_ryuk_filter(session_id, socket) do
      :ok
    else
      error ->
        Logger.info(
          "Failed to connect and register ryuk filter: #{inspect(error)}. Retrying... Attempt #{attempt}/5"
        )

        :timer.sleep(1000)
        connect_and_register_ryuk(container, docker_hostname, session_id, attempt + 1)
    end
  end

  defp connect_and_register_ryuk(_container, _docker_hostname, _session_id, _attempt) do
    {:error, :ryuk_connection_failed}
  end

  defp create_ryuk_socket(container, docker_hostname, reattempt_count \\ 0)

  defp create_ryuk_socket(%Container{} = container, docker_hostname, reattempt_count)
       when reattempt_count < 5 do
    host_port = Container.mapped_port(container, 8080)

    case try_tcp_connect(docker_hostname, host_port) do
      {:ok, connected} ->
        {:ok, connected}

      {:error, reason} ->
        # If connecting via docker_hostname:mapped_port fails and we're in a container,
        # try the container's internal IP on its internal port. In DooD (Docker-outside-of-Docker)
        # both containers are on the same bridge network, so direct IP access works.
        case try_container_internal_connect(container, 8080, reason) do
          {:ok, connected} ->
            {:ok, connected}

          {:error, _} ->
            Logger.info(
              "Connection to Ryuk failed (#{inspect(reason)}). Retrying... Attempt #{reattempt_count + 1}/5"
            )

            :timer.sleep(1000)
            create_ryuk_socket(container, docker_hostname, reattempt_count + 1)
        end
    end
  end

  defp create_ryuk_socket(%Container{} = _container, _docker_hostname, _reattempt_count) do
    Logger.info("Ryuk host refused to connect")
    {:error, :econnrefused}
  end

  defp try_tcp_connect(host, port) do
    :gen_tcp.connect(~c"#{host}", port, [
      :binary,
      active: false,
      packet: :line,
      send_timeout: 10_000
    ], 5000)
  end

  defp try_container_internal_connect(%Container{ip_address: ip}, internal_port, original_reason)
       when is_binary(ip) and ip != "" do
    if running_in_container?() do
      Logger.info(
        "Connection via mapped port failed (#{inspect(original_reason)}). " <>
          "Trying container internal IP #{ip}:#{internal_port}"
      )

      try_tcp_connect(ip, internal_port)
    else
      {:error, original_reason}
    end
  end

  defp try_container_internal_connect(_container, _internal_port, original_reason) do
    {:error, original_reason}
  end

  defp register_ryuk_filter(value, socket) do
    :gen_tcp.send(
      socket,
      "label=#{container_session_id_label()}=#{value}&" <>
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

  defp track_result(self_pid, _config_builder, {:ok, container}) do
    GenServer.cast(self_pid, {:track_container, container.container_id, container.image})
  end

  defp track_result(self_pid, %Container{image: image}, _result) when is_binary(image) do
    GenServer.cast(self_pid, {:track_image, image})
  end

  defp track_result(_self_pid, _config_builder, _result), do: :ok

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
    config = resolve_pull_policy(config, state.properties)

    with :ok <- maybe_pull_image(config, state.conn),
         {:ok, id} <- Api.create_container(config, state.conn),
         :ok <- copy_to_container(id, config, state.conn) do
      start_and_wait_container(id, config, config_builder, state)
    end
  end

  defp resolve_pull_policy(%{pull_policy: nil} = config, properties) do
    pull_policy =
      case Map.get(properties, "pull.policy", "missing") do
        "always" -> PullPolicy.always_pull()
        "never" -> PullPolicy.never_pull()
        _ -> PullPolicy.pull_if_missing()
      end

    %{config | pull_policy: pull_policy}
  end

  defp resolve_pull_policy(config, _properties), do: config

  defp start_and_wait_container(id, config, config_builder, state) do
    with :ok <- Api.start_container(id, state.conn),
         {:ok, container} <- Api.get_container(id, state.conn),
         :ok <- ContainerBuilder.after_start(config_builder, container, state.conn),
         :ok <- wait_for_container(container, config.wait_strategies || [], state.conn) do
      {:ok, container}
    else
      error ->
        Logger.info("Cleaning up container #{id} after failed start")
        Api.stop_container(id, state.conn)
        error
    end
  end

  defp maybe_pull_image(%{pull_policy: %{always_pull: true}} = config, conn) do
    case Api.pull_image(config.image, conn, auth: resolve_auth(config)) do
      {:ok, _nil} -> :ok
      error -> error
    end
  end

  defp maybe_pull_image(%{pull_policy: %{pull_if_missing: true}} = config, conn) do
    case Api.image_exists?(config.image, conn) do
      {:ok, true} ->
        Logger.debug("Image #{config.image} already present locally, skipping pull")
        :ok

      {:ok, false} ->
        case Api.pull_image(config.image, conn, auth: resolve_auth(config)) do
          {:ok, _nil} -> :ok
          error -> error
        end

      error ->
        error
    end
  end

  defp maybe_pull_image(%{pull_policy: %{pull_condition: expr}} = config, conn)
       when is_function(expr) do
    with {:eval, true} <- {:eval, expr.(config, conn)},
         {:ok, _nil} <- Api.pull_image(config.image, conn, auth: resolve_auth(config)) do
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

  # Use the explicitly configured auth if present; otherwise try to
  # auto-resolve credentials from the user's Docker config.
  defp resolve_auth(%{auth: auth}) when is_binary(auth) and auth != "", do: auth
  defp resolve_auth(%{image: image}) when is_binary(image), do: DockerAuth.resolve(image, nil)
  defp resolve_auth(_), do: nil

  defp copy_to_container(id, config, conn) do
    Enum.reduce(config.copy_to, :ok, fn
      copy_to, :ok ->
        CopyTo.copy_to(conn, id, copy_to)

      _, error ->
        error
    end)
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
    socket_override = System.get_env("TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE")

    if socket_override do
      Logger.debug("Using docker socket override: #{socket_override}")

      Container.with_bind_mount(
        config,
        socket_override,
        "/var/run/docker.sock",
        "rw"
      )
    else
      case {os_type(), URI.parse(docker_host)} do
        {os, uri} -> handle_docker_socket_binding(config, os, uri)
      end
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
