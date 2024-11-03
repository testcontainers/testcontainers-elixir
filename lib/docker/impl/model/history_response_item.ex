# NOTE: This file is auto generated by OpenAPI Generator 7.0.1 (https://openapi-generator.tech).
# Do not edit this file manually.

defmodule DockerEngineAPI.Model.HistoryResponseItem do
  @moduledoc """
  individual image layer information in response to ImageHistory operation
  """

  @derive Jason.Encoder
  defstruct [
    :Id,
    :Created,
    :CreatedBy,
    :Tags,
    :Size,
    :Comment
  ]

  @type t :: %__MODULE__{
    :Id => String.t,
    :Created => integer(),
    :CreatedBy => String.t,
    :Tags => [String.t],
    :Size => integer(),
    :Comment => String.t
  }

  def decode(value) do
    value
  end
end

