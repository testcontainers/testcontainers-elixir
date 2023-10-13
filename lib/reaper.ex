# SPDX-License-Identifier: Apache-2.0
defmodule TestcontainersElixir.Reaper do
  use GenServer

  alias DockerEngineAPI.Api
  alias DockerEngineAPI.Model
  alias TestcontainersElixir.Container

  @ryuk_image "testcontainers/ryuk:0.5.1"
  @ryuk_port 8080

  def start_link(connection) do
    GenServer.start_link(__MODULE__, connection, name: __MODULE__)
  end

  def register(filter) do
    GenServer.call(__MODULE__, {:register, filter})
  end

  @impl true
  def init(connection) do
    Process.flag(:trap_exit, true)

    with {:ok, _image_create_response} <-
           Api.Image.image_create(connection, fromImage: @ryuk_image),
         {:ok, %Model.ContainerCreateResponse{Id: container_id}} <-
           create_ryuk_container(connection),
         {:ok, _container_start_response} <-
           Api.Container.container_start(connection, container_id),
         {:ok, %Model.ContainerInspectResponse{} = container_info} <-
           Api.Container.container_inspect(connection, container_id),
         container = Container.of(container_info),
         {:ok, socket} <- create_ryuk_socket(container) do
      {:ok, socket}
    end
  end

  @impl true
  def handle_call({:register, filter}, _from, socket) do
    {:reply, register_filter(socket, filter), socket}
  end

  defp register_filter(socket, {filter_key, filter_value}) do
    :gen_tcp.send(
      socket,
      "#{:uri_string.quote(filter_key)}=#{:uri_string.quote(filter_value)}" <> "\n"
    )

    case :gen_tcp.recv(socket, 0, 1_000) do
      {:ok, "ACK\n"} ->
        :ok

      {:error, :closed} ->
        IO.puts("Connection was closed")
        register_filter(socket, {filter_key, filter_value})

      {:error, reason} ->
        IO.puts("Error receiving data: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp create_ryuk_container(connection) do
    Api.Container.container_create(connection, %Model.ContainerCreateRequest{
      Image: @ryuk_image,
      ExposedPorts: %{"#{@ryuk_port}" => %{}},
      HostConfig: %{
        PortBindings: %{"#{@ryuk_port}" => [%{"HostIp" => "0.0.0.0", "HostPort" => ""}]},
        # FIXME this will surely not work for all use cases
        Binds: ["/var/run/docker.sock:/var/run/docker.sock:rw"]
      },
      Env: ["RYUK_PORT=#{@ryuk_port}", "RYUK_CONNECTION_TIMEOUT=120s"]
    })
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
