defmodule Testcontainers.Compose.ComposeService do
  @moduledoc """
  A lightweight struct representing a service within a Docker Compose environment.
  """

  defstruct [
    :service_name,
    :container_id,
    :state,
    exposed_ports: []
  ]

  @doc """
  Returns the mapped host port for the given container port.
  """
  def mapped_port(%__MODULE__{} = service, port) when is_integer(port) do
    service.exposed_ports
    |> Enum.find_value(nil, fn
      {^port, host_port} -> host_port
      _ -> nil
    end)
  end
end
