# SPDX-License-Identifier: MIT
defmodule Testcontainers.Connection do
  use GenServer

  require Logger

  alias Testcontainers.Container
  alias Testcontainers.Docker.Api
  alias DockerEngineAPI.Connection

  @default_host "unix:///var/run/docker.sock"
  @api_version "v1.41"
  @timeout 300_000

  @doc """
  Eagerly starts this genserver unlinked and waits until it is registered
  """
  def start_eager(opts \\ []) do
    case GenServer.whereis(__MODULE__) do
      nil ->
        start_unlinked(opts)

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
  def init(_) do
    {:ok, get_connection()}
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
    options = Keyword.merge(options, base_url: docker_base_url(), recv_timeout: @timeout)
    Connection.new(options)
  end

  defp docker_base_url do
    case System.get_env("DOCKER_HOST", @default_host) do
      "unix://" <> host -> "http+unix://" <> :uri_string.quote(host) <> "/" <> @api_version
      "tcp://" <> host -> "http://" <> :uri_string.quote(host) <> "/" <> @api_version
    end
  end

  defp start_unlinked(opts) do
    spawn(fn -> GenServer.start(__MODULE__, opts, name: __MODULE__) end)

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
