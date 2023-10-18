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
  @ryuk_filter_label "reaper"

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
  Labels the container so that Ryuk can delete it.
  """
  def label(%Container{} = config) do
    GenServer.call(__MODULE__, {:label, config})
  end

  @impl true
  def init(_) do
    Process.flag(:trap_exit, true)

    with {:ok, container} <- create_ryuk_container(),
         {:ok, socket} <- create_ryuk_socket(container) do
      ryuk_container_id = container.container_id

      Utils.log("Reaper initialized with containerId #{ryuk_container_id}")

      # registers the label filter that ryuk uses to delete containers
      send(self(), {:register, {"label", @ryuk_filter_label, ryuk_container_id}})

      {:ok, %{socket: socket, container: container, id: ryuk_container_id}}
    end
  end

  @impl true
  def handle_call({:label, %Container{} = config}, _from, %{id: ryuk_container_id} = state) do
    config =
      Map.put(
        config,
        :labels,
        Map.put(config.labels, @ryuk_filter_label, ryuk_container_id)
      )

    {:reply, {:ok, config}, state}
  end

  @impl true
  def handle_info({:register, {type, key, value}}, %{socket: socket} = state) do
    :gen_tcp.send(
      socket,
      "#{:uri_string.quote(type)}=#{:uri_string.quote(key)}=#{:uri_string.quote(value)}" <> "\n"
    )

    case :gen_tcp.recv(socket, 0, 1_000) do
      {:ok, "ACK\n"} ->
        {:noreply, state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_ryuk_container do
    %Container{image: @ryuk_image}
    |> Container.with_exposed_port(@ryuk_port)
    |> Container.with_environment("RYUK_PORT", "#{@ryuk_port}")
    |> Container.with_bind_mount("/var/run/docker.sock", "/var/run/docker.sock", "rw")
    |> Container.run(label: false)
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
