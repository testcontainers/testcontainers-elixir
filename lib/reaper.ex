# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule TestcontainersElixir.Reaper do
  use GenServer

  alias TestcontainersElixir.Docker
  alias TestcontainersElixir.Container

  @ryuk_image "testcontainers/ryuk:0.5.1"
  @ryuk_port 8080

  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def register(filter) do
    :ok = ensure_reaper_is_alive()
    GenServer.call(__MODULE__, {:register, filter}, 10000)
  end

  @impl true
  def init(_) do
    with {:ok, container} <- create_ryuk_container(),
         {:ok, socket} <- create_ryuk_socket(container) do
      {:ok, socket}
    else
      error ->
        {:stop, "Failed to start reaper: #{inspect(error)}"}
    end
  end

  @impl true
  def handle_call({:register, filter}, _from, socket) do
    case register(socket, filter) do
      :ok ->
        {:reply, :ok, socket}
      other ->
        {:reply, {:error, "Failed to handle register: #{inspect(other)}"}, socket}
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

      {:error, :closed} ->
        IO.puts("Reaper connection was closed, ignoring")
        :ok

      {:error, reason} ->
        IO.puts("Error receiving data: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp create_ryuk_container do
    %Container{image: @ryuk_image}
    |> Container.with_exposed_port(@ryuk_port)
    |> Container.with_environment("RYUK_PORT", "#{@ryuk_port}")
    |> Container.with_environment("RYUK_CONNECTION_TIMEOUT", "120s")
    |> Container.with_bind_mount("/var/run/docker.sock", "/var/run/docker.sock", "rw")
    |> Docker.Api.run(reap: false)
  end

  defp create_ryuk_socket(%Container{} = container) do
    host_port = Container.mapped_port(container, @ryuk_port)

    :gen_tcp.connect(~c"localhost", host_port, [
      :binary,
      active: false,
      packet: :line
    ])
  end

  defp ensure_reaper_is_alive() do
    case __MODULE__.start_link() do
      {:error, {:already_started, _}} ->
        :ok

      {:ok, _} ->
        :ok

      other ->
        IO.puts("Ignoring unexpected result from starting reaper: #{inspect(other)}")
        :ok
    end
  end
end
