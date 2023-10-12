# SPDX-License-Identifier: Apache-2.0
defmodule TestcontainersElixir do
  @moduledoc """
  Documentation for `TestcontainersElixir`.
  """

  def hello do
    DockerEngineAPI.Connection.new(
      base_url: "http+unix://%2Fvar%2Frun%2Fdocker.sock/v1.43"
    )
    |> DockerEngineAPI.Api.Image.image_list()
  end

end
