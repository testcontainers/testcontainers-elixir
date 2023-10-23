# SPDX-License-Identifier: MIT
defmodule Testcontainers.Connection do
  use GenServer

  @moduledoc """
  This module provides an abstraction for interacting with Docker containers.

  It manages the lifecycle of Docker containers, including creating, starting, and stopping instances, as well as executing commands within running containers. Communication with the Docker daemon is handled through a GenServer, which maintains the state of the connection and executes commands asynchronously.

  ## Examples

  The following examples demonstrate basic usage:

      # Start a new container
      {:ok, container} = Testcontainers.Connection.start_container("my_container_id")

      # Execute a command within a running container
      result = Testcontainers.Connection.exec_create("my_container_id", ["ls"])

  ## Notes

  - This module should be used as a singleton. It is started with the application and should not be manually restarted.
  - All interaction with containers should go through this module to ensure proper connection management and error handling.
  """

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

  # public api

  @doc """
  Starts the GenServer (if it's not already started), enabling the handling of Docker containers.

  This function should typically be called at the start of your application to ensure the GenServer is running.

  ## Parameters

  - `options`: (Optional) A list of options. This can be empty as the defaults are usually sufficient.

  ## Returns

  - `{:ok, pid}` on successful start.
  - `{:error, reason}` on failure.

  ## Examples

      {:ok, pid} = Testcontainers.Connection.start()
  """
  def start(options \\ []) do
    case GenServer.whereis(__MODULE__) do
      nil ->
        start_unlinked(options)

      pid when is_pid(pid) ->
        {:ok, pid}
    end
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

  # internal api

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

  defp get_connection(options) do
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
