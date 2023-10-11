# SPDX-License-Identifier: Apache-2.0
defmodule TestcontainersElixir do
  @moduledoc """
  Documentation for `TestcontainersElixir`.
  """

  def hello do
    :hello.parse_docker_host(System.get_env("DOCKER_HOST", ""))
    |> IO.inspect()
    :hello.fetch_hello("world")
  end
end
