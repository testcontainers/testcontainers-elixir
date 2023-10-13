# SPDX-License-Identifier: Apache-2.0
defmodule TestcontainersElixir.ExUnit do
  alias TestcontainersElixir.CephContainer
  alias TestcontainersElixir.Container
  alias DockerEngineAPI.Model

  def ceph_container(container_config, options \\ []) do
    Container.run(
      container_config,
      options
      |> Keyword.merge(
        on_exit: Keyword.get(options, :on_exit, &ExUnit.Callbacks.on_exit/2),
        waiting_strategy: &CephContainer.waiting_strategy/2
      )
    )
  end

  def generic_container(container_config, options \\ []) do
    Container.run(
      container_config,
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
