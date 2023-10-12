# SPDX-License-Identifier: Apache-2.0
defmodule TestcontainersElixir.ExUnit do

  alias TestcontainersElixir.Reaper
  alias DockerEngineAPI.Connection
  alias DockerEngineAPI.Api
  alias DockerEngineAPI.Model

  defmacro container(options \\ []) do
    quote do
      docker_url = "http+unix://%2Fvar%2Frun%2Fdocker.sock/v1.43"
      conn = Connection.new(base_url: docker_url)

      image = Keyword.get(unquote(options), :image, nil)
      {:ok, _} =
        conn
        |> Api.Image.image_create(fromImage: image)

      port = Keyword.get(unquote(options), :port, nil)

      {:ok, %Model.ContainerCreateResponse{Id: container_id}} =
        conn
        |> Api.Container.container_create(
          %Model.ContainerCreateRequest{
            Image: image,
            ExposedPorts: %{"#{port}" => %{}},
            HostConfig: %{
              PortBindings: %{"#{port}" => [%{"HostPort" => ""}]}
            }
          }
        )

      {:ok, _} =
        conn
        |> Api.Container.container_start(container_id)

      :ok =
        case GenServer.whereis(Reaper) do
          nil ->
            {:ok, _} = conn |> Reaper.start_link()
            Reaper.register({"id", container_id})

          _ ->
            Reaper.register({"id", container_id})

        end

      :ok = Reaper.register({"id", container_id})

      {:ok, container_id}
    end
  end
end
