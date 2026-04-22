defmodule Testcontainers.PullPolicy do
  @moduledoc """
  Pull policies that control whether an image is fetched from a remote registry
  before starting a container.
  """

  alias Testcontainers.PullPolicy

  @type t :: %__MODULE__{
          always_pull: boolean() | nil,
          pull_if_missing: boolean() | nil,
          pull_condition: (struct(), Tesla.Env.t() -> boolean()) | nil
        }

  defstruct [:always_pull, :pull_if_missing, :pull_condition]

  @spec always_pull() :: PullPolicy.t()
  def always_pull do
    %__MODULE__{always_pull: true}
  end

  @spec never_pull() :: PullPolicy.t()
  def never_pull do
    %__MODULE__{}
  end

  @spec pull_if_missing() :: PullPolicy.t()
  def pull_if_missing do
    %__MODULE__{pull_if_missing: true}
  end

  @spec pull_condition(
          expr ::
            (config :: struct(), conn :: Tesla.Env.t() -> true | false)
        ) ::
          PullPolicy.t()
  def pull_condition(expr) do
    %__MODULE__{pull_condition: expr}
  end
end
