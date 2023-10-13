# SPDX-License-Identifier: Apache-2.0
defmodule TestcontainersElixir.Reaper do
  use GenServer

  alias TestcontainersElixir.Connection
  alias TestcontainersElixir.Container

  @ryuk_image "testcontainers/ryuk:0.5.1"
  @ryuk_port 8080

  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def register(filter) do
    GenServer.call(__MODULE__, {:register, filter})
  end

  @impl true
  def init(_) do
    connection = Connection.get_connection()

    with {:ok, container} <- create_ryuk_container(connection),
         {:ok, socket} <- create_ryuk_socket(container) do
      {:ok, socket}
    else
      error ->
        {:stop, "Failed to start reaper: #{inspect(error)}"}
    end
  end

  @impl true
  def handle_call({:register, filter}, _from, socket) do
    {:reply, register(socket, filter), socket}
  end

  defp register(socket, {filter_key, filter_value}, retries \\ 3) do
    :gen_tcp.send(
      socket,
      "#{:uri_string.quote(filter_key)}=#{:uri_string.quote(filter_value)}" <> "\n"
    )

    case :gen_tcp.recv(socket, 0, 1_000) do
      {:ok, "ACK\n"} ->
        :ok

      {:error, :closed} when retries > 0 ->
        IO.puts("Connection was closed, retrying...")
        register(socket, {filter_key, filter_value}, retries - 1)

      {:error, reason} ->
        IO.puts("Error receiving data: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp create_ryuk_container(connection) do
    %Container{image: @ryuk_image}
    |> Container.with_exposed_port(@ryuk_port)
    |> Container.with_environment("RYUK_PORT", "#{@ryuk_port}")
    |> Container.with_environment("RYUK_CONNECTION_TIMEOUT", "120s")
    |> Container.with_bind_mount("/var/run/docker.sock", "/var/run/docker.sock", "rw")
    |> Container.run(connection: connection, reap: false)
  end

  defp create_ryuk_socket(%Container{} = container) do
    host_port = Container.mapped_port(container, @ryuk_port)

    :gen_tcp.connect(~c"localhost", host_port, [
      :binary,
      active: false,
      packet: :line
    ])
  end
end
