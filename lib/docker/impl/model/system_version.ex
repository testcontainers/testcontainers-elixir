# NOTE: This file is auto generated by OpenAPI Generator 7.0.1 (https://openapi-generator.tech).
# Do not edit this file manually.

defmodule DockerEngineAPI.Model.SystemVersion do
  @moduledoc """
  Response of Engine API: GET \"/version\" 
  """

  @derive Jason.Encoder
  defstruct [
    :Platform,
    :Components,
    :Version,
    :ApiVersion,
    :MinAPIVersion,
    :GitCommit,
    :GoVersion,
    :Os,
    :Arch,
    :KernelVersion,
    :Experimental,
    :BuildTime
  ]

  @type t :: %__MODULE__{
    :Platform => DockerEngineAPI.Model.SystemVersionPlatform.t | nil,
    :Components => [DockerEngineAPI.Model.SystemVersionComponentsInner.t] | nil,
    :Version => String.t | nil,
    :ApiVersion => String.t | nil,
    :MinAPIVersion => String.t | nil,
    :GitCommit => String.t | nil,
    :GoVersion => String.t | nil,
    :Os => String.t | nil,
    :Arch => String.t | nil,
    :KernelVersion => String.t | nil,
    :Experimental => boolean() | nil,
    :BuildTime => String.t | nil
  }

  alias DockerEngineAPI.Deserializer

  def decode(value) do
    value
     |> Deserializer.deserialize(:Platform, :struct, DockerEngineAPI.Model.SystemVersionPlatform)
     |> Deserializer.deserialize(:Components, :list, DockerEngineAPI.Model.SystemVersionComponentsInner)
  end
end

