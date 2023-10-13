# SPDX-License-Identifier: Apache-2.0
defmodule TestcontainersElixir.ExUnit do
  alias TestcontainersElixir.Containers

  def container(options \\ []) do
    Containers.container(options, &ExUnit.Callbacks.on_exit/2)
  end
end
