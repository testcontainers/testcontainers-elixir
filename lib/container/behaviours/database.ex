defmodule Testcontainers.DatabaseBehaviour do
  @moduledoc """
  A behaviour implemented by database containers used by `Testcontainers.Ecto`
  """

  @callback new() :: t()
  @callback with_image(t(), String.t()) :: t()
  @callback with_user(t(), String.t()) :: t()
  @callback with_password(t(), String.t()) :: t()
  @callback with_database(t(), String.t()) :: t()
  @callback with_port(t(), integer() | {integer(), integer()}) :: t()
  @callback with_persistent_volume(t(), binary()) :: t()

  @type t :: %{
          :image => String.t(),
          :user => String.t(),
          :password => String.t(),
          :database => String.t(),
          :port => integer() | {integer(), integer()},
          optional(atom()) => any()
        }
end
