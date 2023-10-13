# SPDX-License-Identifier: Apache-2.0
defmodule TestcontainersElixir.ExUnit do
  alias TestcontainersElixir.Reaper
  alias DockerEngineAPI.Connection
  alias DockerEngineAPI.Api
  alias DockerEngineAPI.Model

  def container(options \\ [], on_exit \\ &ExUnit.Callbacks.on_exit/2) do
    docker_url = "http+unix://%2Fvar%2Frun%2Fdocker.sock/v1.43"
    conn = Connection.new(base_url: docker_url)
    image = Keyword.get(options, :image, nil)
    port = Keyword.get(options, :port, nil)

    with {:ok, _} <- Api.Image.image_create(conn, fromImage: image),
         {:ok, container} <- create_simple_container(conn, image, port),
         container_id = container."Id",
         {:ok, _} <- Api.Container.container_start(conn, container_id),
         :ok =
           on_exit.(:stop_container, fn ->
             with :ok <- reap_container(conn, container_id) do
               stop_container(conn, container_id)
             end
           end) do
      {:ok, get_container(conn, container_id)}
    end
  end

  defp stop_container(conn, container_id) when is_binary(container_id) do
    with {:ok, _} <- Api.Container.container_kill(conn, container_id),
         {:ok, _} <- Api.Container.container_delete(conn, container_id) do
      :ok
    end
  end

  defp create_simple_container(conn, image, port) when is_binary(image) and is_number(port) do
    Api.Container.container_create(conn, %Model.ContainerCreateRequest{
      Image: image,
      ExposedPorts: %{"#{port}" => %{}},
      HostConfig: %{
        PortBindings: %{"#{port}/tcp" => [%{"HostIp" => "0.0.0.0", "HostPort" => ""}]}
      }
    })
  end

  defp get_container(conn, container_id) when is_binary(container_id) do
    with {:ok, response} <- Api.Container.container_inspect(conn, container_id) do
      TestcontainersElixir.Container.of(response)
    end
  end

  defp reap_container(conn, container_id) when is_binary(container_id) do
    case GenServer.whereis(Reaper) do
      nil ->
        {:ok, _} = conn |> Reaper.start_link()
        Reaper.register({"id", container_id})

      _ ->
        Reaper.register({"id", container_id})
    end
  end
end
