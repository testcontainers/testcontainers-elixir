# SPDX-License-Identifier: Apache-2.0
defmodule TestcontainersElixir do
  @moduledoc """
  Documentation for `TestcontainersElixir`.
  """

  def hello do
    connection =
      DockerEngineAPI.Connection.new(base_url: "http+unix://%2Fvar%2Frun%2Fdocker.sock/v1.43")
    {:ok, _pid} = connection |> TestcontainersElixir.Reaper.start_link()
    connection |> DockerEngineAPI.Api.Image.image_list()
  end
end
