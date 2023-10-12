# SPDX-License-Identifier: Apache-2.0
defmodule TestcontainersElixir.Reaper do
  use GenServer

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
    {:ok, _} =
      connection
      |> DockerEngineAPI.Api.Image.image_create(fromImage: @ryuk_image)

    {:ok, %DockerEngineAPI.Model.ContainerCreateResponse{Id: container_id} = container} =
      connection
      |> DockerEngineAPI.Api.Container.container_create(
        %DockerEngineAPI.Model.ContainerCreateRequest{
          Image: @ryuk_image,
          ExposedPorts: %{"#{@ryuk_port}" => %{}},
          HostConfig: %{
            PortBindings: %{"#{@ryuk_port}" => [%{"HostPort" => ""}]},
            Privileged: true,
            Binds: ["/var/run/docker.sock:/var/run/docker.sock:rw"]
          },
          Env: ["RYUK_PORT=8080"]
        }
      )

    {:ok, _} =
      connection
      |> DockerEngineAPI.Api.Container.container_start(container_id)

    {:ok, socket} =
      connection
      |> create_socket(container, @ryuk_port)

    {:ok, socket}
  end

  @impl true
  def handle_call({:register, filter}, _from, socket) do
    {:reply, do_register(socket, filter), socket}
  end

  defp do_register(socket, {filter_key, filter_value}) do
    :gen_tcp.send(
      socket,
      "#{:uri_string.quote(filter_key)}=#{:uri_string.quote(filter_value)}" <> "\n"
    )

    {:ok, "ACK\n"} = :gen_tcp.recv(socket, 0, 1_000)

    :ok
  end

  defp create_socket(
         connection,
         %DockerEngineAPI.Model.ContainerCreateResponse{Id: container_id},
         port
       ) do
    port_str = "#{port}/tcp"

    {:ok,
     %DockerEngineAPI.Model.ContainerInspectResponse{
       NetworkSettings: %{Ports: %{^port_str => [%{"HostPort" => host_port}]}}
     }} = connection |> DockerEngineAPI.Api.Container.container_inspect(container_id)

    :gen_tcp.connect(~c"localhost", String.to_integer(host_port), [
      :binary,
      active: false,
      packet: :line
    ])
  end
end
