# SPDX-License-Identifier: MIT
defmodule Testcontainers.Connection do
  use GenServer

  alias Testcontainers.Utils

  alias Testcontainers.Connection.DockerHostStrategyEvaluator
  alias Testcontainers.Connection.DockerHostStrategy.DockerSocketPath
  alias Testcontainers.Connection.DockerHostStrategy.DockerHostFromProperties
  alias Testcontainers.Connection.DockerHostStrategy.DockerHostFromEnv
  alias Testcontainers.Connection.DockerHostStrategy.DockerHostFromProperties
  alias Testcontainers.Container
  alias Testcontainers.Docker.Api
  alias DockerEngineAPI.Connection

  @api_version "v1.41"
  @timeout 300_000

  @doc """
  Eagerly starts this genserver unlinked and waits until it is registered
  """
  def start_eager(options \\ []) do
    case GenServer.whereis(__MODULE__) do
      nil ->
        start_unlinked(options)

      pid when is_pid(pid) ->
        {:ok, pid}
    end
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def pull_image(image) when is_binary(image) do
    GenServer.call(__MODULE__, {:pull_image, image}, 300_000)
  end

  def create_container(%Container{} = container) do
    GenServer.call(__MODULE__, {:create_container, container}, 300_000)
  end

  def start_container(container_id) when is_binary(container_id) do
    GenServer.call(__MODULE__, {:start_container, container_id}, 300_000)
  end

  def stop_container(container_id) when is_binary(container_id) do
    GenServer.call(__MODULE__, {:stop_container, container_id}, 300_000)
  end

  def get_container(container_id) when is_binary(container_id) do
    GenServer.call(__MODULE__, {:get_container, container_id}, 300_000)
  end

  def stdout_logs(container_id) when is_binary(container_id) do
    GenServer.call(__MODULE__, {:stdout_logs, container_id}, 300_000)
  end

  def exec_create(container_id, command) when is_binary(container_id) and is_list(command) do
    GenServer.call(__MODULE__, {:exec_create, command, container_id}, 300_000)
  end

  def exec_start(exec_id) when is_binary(exec_id) do
    GenServer.call(__MODULE__, {:exec_start, exec_id}, 300_000)
  end

  def exec_inspect(exec_id) when is_binary(exec_id) do
    GenServer.call(__MODULE__, {:exec_inspect, exec_id}, 300_000)
  end

  @impl true
  def init(options) do
    {:ok, get_connection(options)}
  end

  @impl true
  def handle_call({:pull_image, image}, _from, connection) do
    {:reply, Api.pull_image(image, connection), connection}
  end

  @impl true
  def handle_call({:get_container, container_id}, _from, connection) do
    {:reply, Api.get_container(container_id, connection), connection}
  end

  @impl true
  def handle_call({:start_container, container_id}, _from, connection) do
    {:reply, Api.start_container(container_id, connection), connection}
  end

  @impl true
  def handle_call({:create_container, %Container{} = container}, _from, connection) do
    {:reply, Api.create_container(container, connection), connection}
  end

  @impl true
  def handle_call({:stop_container, container_id}, _from, connection) do
    {:reply, Api.stop_container(container_id, connection), connection}
  end

  @impl true
  def handle_call({:stdout_logs, container_id}, _from, connection) do
    {:reply, Api.stdout_logs(container_id, connection), connection}
  end

  @impl true
  def handle_call({:exec_create, command, container_id}, _from, connection) do
    {:reply, Api.create_exec(container_id, command, connection), connection}
  end

  @impl true
  def handle_call({:exec_start, exec_id}, _from, connection) do
    {:reply, Api.start_exec(exec_id, connection), connection}
  end

  @impl true
  def handle_call({:exec_inspect, exec_id}, _from, connection) do
    {:reply, Api.inspect_exec(exec_id, connection), connection}
  end

  def get_connection(options \\ []) do
    docker_host_url = docker_base_url()

    Utils.log("Using docker host url: #{docker_host_url}")

    options = Keyword.merge(options, base_url: docker_host_url, recv_timeout: @timeout)

    Connection.new(options)
  end

  defp docker_base_url do
    strategies = [
      %DockerHostFromProperties{key: "tc.host"},
      %DockerHostFromEnv{},
      %DockerSocketPath{socket_paths: ["/var/run/docker.sock"]},
      %DockerHostFromProperties{key: "docker.host"},
      %DockerSocketPath{}
    ]

    case DockerHostStrategyEvaluator.run_strategies(strategies, []) do
      {:ok, "unix://" <> path} ->
        "http+unix://#{:uri_string.quote(path)}/#{@api_version}"

      {:ok, docker_host} ->
        construct_url_from_docker_host(docker_host)

      :error ->
        exit("Failed to find docker host")
    end
  end

  defp construct_url_from_docker_host(docker_host) do
    uri = URI.parse(docker_host)

    case uri do
      %URI{scheme: "tcp"} ->
        URI.to_string(%{uri | scheme: "http", path: "/#{@api_version}"})

      %URI{scheme: _, authority: _} = uri ->
        URI.to_string(%{uri | path: "/#{@api_version}"})
    end
  end

  defp start_unlinked(options) do
    spawn(fn -> GenServer.start(__MODULE__, options, name: __MODULE__) end)

    wait_for_start(__MODULE__, 10_000)
  end

  defp wait_for_start(name, timeout) do
    wait_for_start(name, timeout, :timer.seconds(1))
  end

  defp wait_for_start(_name, 0, _interval), do: {:error, :timeout}

  defp wait_for_start(name, remaining_time, interval) do
    case GenServer.whereis(name) do
      nil ->
        Process.sleep(interval)
        wait_for_start(name, remaining_time - interval, interval)

      pid when is_pid(pid) ->
        {:ok, pid}
    end
  end
end
