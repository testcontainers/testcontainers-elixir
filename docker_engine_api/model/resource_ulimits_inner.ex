# NOTE: This file is auto generated by OpenAPI Generator 7.0.1 (https://openapi-generator.tech).
# Do not edit this file manually.

defmodule DockerEngineAPI.Model.ResourcesUlimitsInner do
  @moduledoc """

  """

  @derive Jason.Encoder
  defstruct [
    :Name,
    :Soft,
    :Hard
  ]

  @type t :: %__MODULE__{
    :Name => String.t | nil,
    :Soft => integer() | nil,
    :Hard => integer() | nil
  }

  def decode(value) do
    value
  end
end
