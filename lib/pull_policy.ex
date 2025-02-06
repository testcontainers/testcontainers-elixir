defmodule Testcontainers.PullPolicy do
  alias Testcontainers.PullPolicy

  defstruct [:always_pull, :pull_condition]

  @spec always_pull() :: %PullPolicy{}
  def always_pull do
    %__MODULE__{always_pull: true}
  end

  @spec never_pull() :: %PullPolicy{}
  def never_pull do
    %__MODULE__{}
  end

  @spec pull_condition(
          expr ::
            (config :: struct(), conn :: Tesla.Env.t() -> true | false)
        ) ::
          %PullPolicy{}
  def pull_condition(expr) do
    %__MODULE__{pull_condition: expr}
  end
end
