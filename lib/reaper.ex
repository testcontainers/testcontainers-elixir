# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule Testcontainers.Reaper do
  use GenServer

  alias Testcontainers.Utils

  alias Testcontainers.Container

  @ryuk_image "testcontainers/ryuk:0.5.1"
  @ryuk_port 8080

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

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

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
