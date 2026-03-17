defmodule Testcontainers.Compose.ComposeEnvironment do
  @moduledoc """
  Represents the started state of a Docker Compose environment.
  """

  alias Testcontainers.Compose.ComposeService

  defstruct [:compose, :project_name, :docker_host, services: %{}]

  @doc """
  Returns the service struct for the given service name.
  """
  def get_service(%__MODULE__{} = env, service_name) when is_binary(service_name) do
    Map.get(env.services, service_name)
  end

  @doc """
  Returns the docker host for a service.
  """
  def get_service_host(%__MODULE__{} = env, _service_name) do
    env.docker_host
  end

  @doc """
  Returns the mapped host port for a service and container port.
  """
  def get_service_port(%__MODULE__{} = env, service_name, port)
      when is_binary(service_name) and is_integer(port) do
    case get_service(env, service_name) do
      nil -> nil
      service -> ComposeService.mapped_port(service, port)
    end
  end
end
