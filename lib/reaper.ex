# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule Testcontainers.Reaper do
  use GenServer

  @moduledoc """
  A GenServer that manages the lifecycle of the Ryuk container within the Testcontainers ecosystem.

  The Reaper is responsible for ensuring that resources are cleaned up properly when test containers
  are no longer needed. It communicates with the Ryuk container, a tool used by Testcontainers to
  reap orphaned containers.

  ## Usage

  The module is typically used in the context of integration tests where test containers are
  employed. It starts the Ryuk container and registers filters for cleaning up resources.

  It is meant to be started before interacting with any test containers and stopped after all tests
  are concluded.

  Note: This is an internal component and should not be used directly in tests. Instead, it's used
  by the higher-level Testcontainers APIs.
  """

  alias Testcontainers.Utils

  alias Testcontainers.Container

  @ryuk_image "testcontainers/ryuk:0.5.1"
  @ryuk_port 8080

  @doc """
  Starts the Reaper process if it is not already running.

  This function will start the Reaper unlinked (outside of the current supervision tree)
  and wait until it's registered with the local process registry.

  It's particularly useful for scenarios where the Reaper needs to be started without a
  linked supervision strategy, often before the actual test scenarios are executed.

  ## Examples

      iex> Testcontainers.Reaper.start_eager()
      {:ok, pid}

  ## Options

  The function accepts an optional list of options (`opts`) that are passed to the GenServer
  initialization, though in the current implementation, these options are not used.

  ## Errors

  If the Reaper fails to start, the function will return an error tuple.

  ## Note

  This function is designed to be used in setup scenarios, possibly within test suite setup
  callbacks.
  """
  def start_eager(opts \\ []) do
    case GenServer.whereis(__MODULE__) do
      nil ->
        start_unlinked(opts)

      pid when is_pid(pid) ->
        {:ok, pid}
    end
  end

  @doc """
  Registers a filter with the Ryuk container for resources to be reaped.

  This function sends a message to the Reaper, which communicates with the Ryuk container
  to establish a filter based on the provided criteria. Resources that match the filter will
  be monitored and cleaned up by Ryuk once they are no longer needed.

  ## Examples

      iex> Testcontainers.Reaper.register({"label", "com.example.test-session"})
      :ok

  ## Parameters

  - `filter`: A tuple representing the filter key and value. Resources within the scope of
    Testcontainers that match this filter will be eligible for cleanup.

  ## Note

  The function is a cast operation; it does not return any value and will silently fail if
  there's an issue. It's designed to be fire-and-forget for setting up cleanup filters,
  to avoid tests failing if the reaper is not running.
  """
  def register(filter) do
    GenServer.cast(__MODULE__, {:register, filter})
  end

  @impl true
  def init(_) do
    Process.flag(:trap_exit, true)

    with {:ok, container} <- create_ryuk_container(),
         {:ok, socket} <- create_ryuk_socket(container) do
      Utils.log("Reaper initialized with containerId #{container.container_id}")

      {:ok, %{socket: socket, container: container}}
    end
  end

  @impl true
  def handle_cast({:register, filter}, %{socket: socket} = state) do
    case register(socket, filter) do
      :ok ->
        {:noreply, state}

      {:error, _reason} ->
        {:stop, :error_reason, state}
    end
  end

  defp register(socket, {filter_key, filter_value}) do
    :gen_tcp.send(
      socket,
      "#{:uri_string.quote(filter_key)}=#{:uri_string.quote(filter_value)}" <> "\n"
    )

    case :gen_tcp.recv(socket, 0, 1_000) do
      {:ok, "ACK\n"} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_ryuk_container do
    %Container{image: @ryuk_image}
    |> Container.with_exposed_port(@ryuk_port)
    |> Container.with_environment("RYUK_PORT", "#{@ryuk_port}")
    |> Container.with_environment("RYUK_CONNECTION_TIMEOUT", "120s")
    |> Container.with_bind_mount("/var/run/docker.sock", "/var/run/docker.sock", "rw")
    |> Container.run()
  end

  defp create_ryuk_socket(%Container{} = container) do
    host_port = Container.mapped_port(container, @ryuk_port)

    :gen_tcp.connect(~c"localhost", host_port, [
      :binary,
      active: false,
      packet: :line
    ])
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
