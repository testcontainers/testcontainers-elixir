# SPDX-License-Identifier: Apache-2.0
defmodule TestcontainersElixir do
  @moduledoc """
  Documentation for `TestcontainersElixir`.
  """

  alias TestcontainersElixir.Reaper
  alias DockerEngineAPI.Connection
  alias DockerEngineAPI.Api

  def hello do
    docker_url = "http+unix://%2Fvar%2Frun%2Fdocker.sock/v1.43"

    conn = Connection.new(base_url: docker_url)

    # TODO create a container, gets its container id and pass it to the next line

    :ok = conn |> register_container("some_container_id")

    conn |> Api.Image.image_list()
  end

  defp register_container(conn, container_id) when is_binary(container_id) do
    case Reaper.ping() do
      :ok ->
        Reaper.register({"id", container_id})

      :error ->
        {:ok, _} = conn |> Reaper.start_link()
        Reaper.register({"id", container_id})
    end
  end
end
