# NOTE: This file is auto generated by OpenAPI Generator 7.0.1 (https://openapi-generator.tech).
# Do not edit this file manually.

defmodule DockerEngineAPI.Model.ServiceSpecModeReplicated do
  @moduledoc """
  
  """

  @derive Jason.Encoder
  defstruct [
    :Replicas
  ]

  @type t :: %__MODULE__{
    :Replicas => integer() | nil
  }

  def decode(value) do
    value
  end
end

