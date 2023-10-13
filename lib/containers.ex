# SPDX-License-Identifier: Apache-2.0
defmodule TestcontainersElixir.Containers do
  alias TestcontainersElixir.PortChecker
  alias DockerEngineAPI.Api
  alias DockerEngineAPI.Connection
  alias TestcontainersElixir.Reaper
  alias TestcontainersElixir.Container

  def container(options) do
    conn = Keyword.get_lazy(options, :conn, &get_static_connection/0)
    image = Keyword.get(options, :image, nil)
    port = Keyword.get(options, :port, nil)
    on_exit = Keyword.get(options, :on_exit, fn _, _ -> :ok end)
    container_factory = Keyword.get(options, :container_factory)

    waiting_strategy =
      Keyword.get(options, :waiting_strategy, fn _ ->
        PortChecker.wait_for_port("127.0.0.1", port)
      end)

    with {:ok, _} <- Api.Image.image_create(conn, fromImage: image),
         {:ok, container} <- Api.Container.container_create(conn, container_factory.(options)),
         container_id = container."Id",
         {:ok, _} <- Api.Container.container_start(conn, container_id),
         :ok =
           on_exit.(:stop_container, fn ->
             with :ok <- reap_container(conn, container_id) do
               stop_container(conn, container_id)
             end
           end),
         {:ok, container} <- get_container(conn, container_id),
         {:ok, _} <- waiting_strategy.(conn, container) do
      {:ok, container}
    end
  end

  defp stop_container(conn, container_id) when is_binary(container_id) do
    with {:ok, _} <- Api.Container.container_kill(conn, container_id),
         {:ok, _} <- Api.Container.container_delete(conn, container_id) do
      :ok
    end
  end

  defp get_container(conn, container_id) when is_binary(container_id) do
    with {:ok, response} <- Api.Container.container_inspect(conn, container_id) do
      {:ok, Container.of(response)}
    end
  end

  defp reap_container(conn, container_id) when is_binary(container_id) do
    case conn |> Reaper.start_link() do
      {:error, {:already_started, _}} -> :ok
      {:ok, _} -> :ok
    end

    Reaper.register({"id", container_id})
  end

  defp get_static_connection,
    do: Connection.new(base_url: "http+unix://%2Fvar%2Frun%2Fdocker.sock/v1.43")
end
