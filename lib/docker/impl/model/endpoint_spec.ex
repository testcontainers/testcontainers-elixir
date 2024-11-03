# NOTE: This file is auto generated by OpenAPI Generator 7.0.1 (https://openapi-generator.tech).
# Do not edit this file manually.

defmodule DockerEngineAPI.Model.EndpointSpec do
  @moduledoc """
  Properties that can be configured to access and load balance a service.
  """

  @derive Jason.Encoder
  defstruct [
    :Mode,
    :Ports
  ]

  @type t :: %__MODULE__{
    :Mode => String.t | nil,
    :Ports => [DockerEngineAPI.Model.EndpointPortConfig.t] | nil
  }

  alias DockerEngineAPI.Deserializer

  def decode(value) do
    value
     |> Deserializer.deserialize(:Ports, :list, DockerEngineAPI.Model.EndpointPortConfig)
  end
end

