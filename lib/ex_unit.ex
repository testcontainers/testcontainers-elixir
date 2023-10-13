# SPDX-License-Identifier: Apache-2.0
defmodule TestcontainersElixir.ExUnit do
  alias TestcontainersElixir.CephContainer
  alias TestcontainersElixir.Containers
  alias DockerEngineAPI.Model

  def ceph_container(options \\ []) do
    Containers.container(
      options
      |> Keyword.merge(
        on_exit: Keyword.get(options, :on_exit, &ExUnit.Callbacks.on_exit/2),
        container_factory: &CephContainer.create_container/1,
        waiting_strategy: &CephContainer.waiting_strategy/2
      )
    )
  end

  def generic_container(options \\ []) do
    Containers.container(
      options
      |> Keyword.merge(
        on_exit: Keyword.get(options, :on_exit, &ExUnit.Callbacks.on_exit/2),
        container_factory: fn _ ->
          %Model.ContainerCreateRequest{
            Image: Keyword.get(options, :image),
            ExposedPorts: %{"#{Keyword.get(options, :port)}" => %{}},
            HostConfig: %{
              PortBindings: %{
                "#{Keyword.get(options, :port)}" => [
                  %{"HostIp" => "0.0.0.0", "HostPort" => ""}
                ]
              }
            }
          }
        end
      )
    )
  end
end
