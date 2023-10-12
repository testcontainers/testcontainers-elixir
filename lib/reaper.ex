defmodule TestcontainersElixir.Reaper do
  use GenServer

  @impl true
  @spec init(Tesla.Env.client()) :: {:ok, DockerEngineAPI.Model.ContainerCreateResponse.t()}
  def init(connection) do
    request = %DockerEngineAPI.Model.ContainerCreateRequest{
      Image: "testcontainers/ryuk:0.5.1",
      ExposedPorts: %{"8080" => %{}},
      HostConfig: %{
        PortBindings: %{"8080" => [%{"HostPort" => "8080"}]},
        Privileged: true,
        Binds: ["/var/run/docker.sock:/var/run/docker.sock:rw"]
      },
      Env: ["RYUK_PORT=8080"]
    }

    {:ok, container} = connection |> DockerEngineAPI.Api.Container.container_create(request)
    {:ok, container} = connection |> DockerEngineAPI.Api.Container.container_start(container."Id")
    # TODO establish socket connection
    # TODO send first message
    # TODO return {:ok, {container, socket}} for ex
    {:ok, container}
  end
end
