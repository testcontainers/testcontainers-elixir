# SPDX-License-Identifier: Apache-2.0
defmodule TestcontainersElixir.Container do
  alias DockerEngineAPI.Model.ContainerInspectResponse

  defstruct [:container_id, ports: %{}]

  def of(%ContainerInspectResponse{
        Id: container_id,
        NetworkSettings: %{Ports: ports}
      }) do
    %__MODULE__{
      container_id: container_id,
      ports:
        Enum.reduce(ports || [], [], fn {key, ports}, acc ->
          acc ++
            Enum.map(ports || [], fn %{"HostIp" => host_ip, "HostPort" => host_port} ->
              %{exposed_port: key, host_ip: host_ip, host_port: host_port |> String.to_integer()}
            end)
        end)
    }
  end

  def mapped_port(%__MODULE__{} = container, port) when is_number(port) do
    container.ports
    |> Enum.filter(fn %{exposed_port: exposed_port} -> exposed_port == "#{port}/tcp" end)
    |> List.first(%{})
    |> Map.get(:host_port)
  end
end
