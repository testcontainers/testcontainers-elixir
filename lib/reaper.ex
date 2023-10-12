# SPDX-License-Identifier: Apache-2.0
defmodule TestcontainersElixir.Reaper do
  use GenServer

  @ryuk_image "testcontainers/ryuk:0.5.1"
  @ryuk_port 8080

  def start_link(connection) do
    GenServer.start_link(__MODULE__, connection)
  end

  def init(connection) do
    {:ok, _} =
      connection
      |> DockerEngineAPI.Api.Image.image_create(fromImage: @ryuk_image)

    {:ok, container} =
      connection
      |> DockerEngineAPI.Api.Container.container_create(
        %DockerEngineAPI.Model.ContainerCreateRequest{
          Image: @ryuk_image,
          ExposedPorts: %{"#{@ryuk_port}" => %{}},
          HostConfig: %{
            PortBindings: %{"8080" => [%{"HostPort" => ""}]},
            Privileged: true,
            Binds: ["/var/run/docker.sock:/var/run/docker.sock:rw"]
          },
          Env: ["RYUK_PORT=8080"]
        }
      )

    {:ok, container} =
      connection
      |> DockerEngineAPI.Api.Container.container_start(container."Id")

    # TODO establish socket connection
    # TODO send first message
    # TODO return {:ok, {container, socket}} for ex
    {:ok, container}
  end
end
